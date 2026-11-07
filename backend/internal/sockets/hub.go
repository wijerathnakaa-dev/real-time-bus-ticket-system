package sockets

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

const (
	writeWait  = 10 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = 50 * time.Second
)

// Client is one connected device. A client with busID == "" receives every event
// (admin dashboard); otherwise only events for that bus.
type Client struct {
	hub   *Hub
	conn  *websocket.Conn
	send  chan []byte
	busID string
}

type message struct {
	busID string
	data  []byte
}

type Hub struct {
	clients    map[*Client]bool
	broadcast  chan message
	register   chan *Client
	unregister chan *Client
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan message, 256),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case c := <-h.register:
			h.clients[c] = true
		case c := <-h.unregister:
			if _, ok := h.clients[c]; ok {
				delete(h.clients, c)
				close(c.send)
			}
		case m := <-h.broadcast:
			for c := range h.clients {
				if c.busID != "" && m.busID != "" && c.busID != m.busID {
					continue
				}
				select {
				case c.send <- m.data:
				default: // slow client: drop it, it will reconnect and resync
					delete(h.clients, c)
					close(c.send)
				}
			}
		}
	}
}

// BroadcastBus sends an event to subscribers of busID and to all-bus subscribers.
func (h *Hub) BroadcastBus(busID string, v interface{}) {
	data, err := json.Marshal(v)
	if err != nil {
		return
	}
	select {
	case h.broadcast <- message{busID: busID, data: data}:
	default:
		log.Println("[WebSocket] broadcast queue full, dropping event")
	}
}

// BroadcastJSON sends an event to every client.
func (h *Hub) BroadcastJSON(v interface{}) { h.BroadcastBus("", v) }

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("[WebSocket] Upgrade error:", err)
		return
	}
	client := &Client{hub: hub, conn: conn, send: make(chan []byte, 256), busID: r.URL.Query().Get("bus_id")}
	hub.register <- client
	go client.writePump()
	go client.readPump()
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(4096)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error { return c.conn.SetReadDeadline(time.Now().Add(pongWait)) })
	for {
		if _, _, err := c.conn.ReadMessage(); err != nil {
			return
		}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, nil)
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
