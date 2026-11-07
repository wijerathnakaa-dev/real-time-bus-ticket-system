// Package realtime mirrors live state (seat maps, bus positions, ETAs) to Firebase
// Realtime Database and sends Firebase Cloud Messaging pushes. MySQL stays the
// system of record; Firebase is the low-latency fan-out store for devices.
//
// It authenticates with a service-account JSON file over plain REST, so it adds no
// heavy SDK. When the file or database URL is missing it becomes a no-op.
package realtime

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
)

type Firebase struct {
	dbURL     string
	projectID string
	client    *http.Client
	jobs      chan func()
}

// New returns nil (a disabled mirror) when Firebase is not configured.
func New(credentialsFile, databaseURL string) *Firebase {
	raw, err := os.ReadFile(credentialsFile)
	if err != nil {
		log.Printf("[Firebase] disabled: %s not found (live data still flows over WebSocket)", credentialsFile)
		return nil
	}
	var meta struct {
		ProjectID string `json:"project_id"`
	}
	_ = json.Unmarshal(raw, &meta)
	creds, err := google.CredentialsFromJSON(context.Background(), raw,
		"https://www.googleapis.com/auth/firebase.database",
		"https://www.googleapis.com/auth/userinfo.email",
		"https://www.googleapis.com/auth/firebase.messaging",
	)
	if err != nil {
		log.Printf("[Firebase] disabled: invalid service account: %v", err)
		return nil
	}
	if databaseURL == "" && meta.ProjectID != "" {
		databaseURL = fmt.Sprintf("https://%s-default-rtdb.asia-southeast1.firebasedatabase.app", meta.ProjectID)
	}
	f := &Firebase{
		dbURL:     strings.TrimRight(databaseURL, "/"),
		projectID: meta.ProjectID,
		client:    oauth2.NewClient(context.Background(), creds.TokenSource),
		jobs:      make(chan func(), 512),
	}
	f.client.Timeout = 10 * time.Second
	go func() {
		for job := range f.jobs {
			job()
		}
	}()
	log.Printf("[Firebase] mirroring live data to %s", f.dbURL)
	return f
}

func (f *Firebase) enqueue(job func()) {
	select {
	case f.jobs <- job:
	default:
		log.Println("[Firebase] queue full, dropping update")
	}
}

// Set writes value at path (e.g. "buses/bus_1/seats") asynchronously.
func (f *Firebase) Set(path string, value interface{}) {
	if f == nil {
		return
	}
	f.enqueue(func() {
		body, _ := json.Marshal(value)
		req, _ := http.NewRequest(http.MethodPut, fmt.Sprintf("%s/%s.json", f.dbURL, strings.Trim(path, "/")), bytes.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if resp, err := f.client.Do(req); err != nil {
			log.Printf("[Firebase] RTDB write %s failed: %v", path, err)
		} else {
			resp.Body.Close()
			if resp.StatusCode >= 300 {
				log.Printf("[Firebase] RTDB write %s: HTTP %d", path, resp.StatusCode)
			}
		}
	})
}

// NotifyTopic sends an FCM push to every device subscribed to topic.
func (f *Firebase) NotifyTopic(topic, title, body string, data map[string]string) {
	if f == nil || f.projectID == "" {
		return
	}
	f.enqueue(func() {
		payload, _ := json.Marshal(map[string]interface{}{
			"message": map[string]interface{}{
				"topic":        topic,
				"notification": map[string]string{"title": title, "body": body},
				"data":         data,
			},
		})
		url := fmt.Sprintf("https://fcm.googleapis.com/v1/projects/%s/messages:send", f.projectID)
		if resp, err := f.client.Post(url, "application/json", bytes.NewReader(payload)); err != nil {
			log.Printf("[Firebase] FCM to %s failed: %v", topic, err)
		} else {
			resp.Body.Close()
		}
	})
}
