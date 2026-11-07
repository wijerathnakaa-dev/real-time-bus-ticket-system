// Package payments integrates PayHere (Sri Lanka). With PAYHERE_MERCHANT_ID and
// PAYHERE_MERCHANT_SECRET set it runs the real (sandbox or live) hosted checkout
// and verifies PayHere's server-to-server notification signature. Without them it
// exposes a clearly-labelled "simulated" payment so the flow can be demoed.
package payments

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strings"

	"real-time-bus-backend/internal/app"
	"real-time-bus-backend/internal/modules/tickets"

	"github.com/gin-gonic/gin"
)

func md5Upper(s string) string {
	h := md5.Sum([]byte(s))
	return strings.ToUpper(hex.EncodeToString(h[:]))
}

func amount(f float64) string { return fmt.Sprintf("%.2f", f) }

func sign(d *app.Deps, ticketID string) string {
	m := hmac.New(sha256.New, []byte(d.Cfg.JWTSecret))
	m.Write([]byte("payhere:" + ticketID))
	return hex.EncodeToString(m.Sum(nil))[:32]
}

func mode(d *app.Deps) string {
	if !d.Cfg.PayHereEnabled() {
		return "simulated"
	}
	if d.Cfg.PayHereSandbox {
		return "sandbox"
	}
	return "live"
}

var checkoutTmpl = template.Must(template.New("c").Parse(`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Redirecting to PayHere</title></head>
<body style="font-family:sans-serif;text-align:center;padding-top:40px">
<p>Redirecting to PayHere&hellip;</p>
<form id="f" method="post" action="{{.Action}}">{{range $k, $v := .Fields}}<input type="hidden" name="{{$k}}" value="{{$v}}">{{end}}
<button type="submit">Continue to payment</button></form>
<script>document.getElementById('f').submit()</script></body></html>`))

func RegisterRoutes(rg *gin.RouterGroup, d *app.Deps) {
	rg.GET("/config", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"provider": "payhere", "mode": mode(d), "currency": "LKR"})
	})

	// Start payment for a pending in-app ticket.
	rg.POST("/start", d.Auth(app.RolePassenger), func(c *gin.Context) {
		var req struct {
			TicketID string `json:"ticket_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		t, err := tickets.Load(d.DB, req.TicketID)
		if err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		if t.PassengerID == nil || *t.PassengerID != app.User(c).UserID {
			app.Fail(c, http.StatusForbidden, "not your ticket")
			return
		}
		if t.PaymentStatus != "pending" || t.Status != "active" {
			app.Fail(c, http.StatusConflict, "ticket is not awaiting payment")
			return
		}
		m := mode(d)
		resp := gin.H{"mode": m, "ticket_id": t.ID, "amount": t.Fare, "currency": "LKR"}
		if m != "simulated" {
			resp["checkout_url"] = fmt.Sprintf("%s/api/v1/payments/payhere/checkout/%s?sig=%s", d.Cfg.PublicBaseURL, t.ID, sign(d, t.ID))
		}
		c.JSON(http.StatusOK, resp)
	})

	// Browser page that auto-posts the signed order to PayHere's hosted checkout.
	rg.GET("/payhere/checkout/:ticket", func(c *gin.Context) {
		id := c.Param("ticket")
		if !d.Cfg.PayHereEnabled() || !hmac.Equal([]byte(c.Query("sig")), []byte(sign(d, id))) {
			c.String(http.StatusForbidden, "invalid or expired payment link")
			return
		}
		t, err := tickets.Load(d.DB, id)
		if err != nil || t.PaymentStatus != "pending" {
			c.String(http.StatusConflict, "ticket is not awaiting payment")
			return
		}
		action := "https://www.payhere.lk/pay/checkout"
		if d.Cfg.PayHereSandbox {
			action = "https://sandbox.payhere.lk/pay/checkout"
		}
		amt := amount(t.Fare)
		var email, phone string
		if t.PassengerID != nil {
			_ = d.DB.QueryRow(`SELECT email, COALESCE(phone,'') FROM users WHERE id=?`, *t.PassengerID).Scan(&email, &phone)
		}
		fields := map[string]string{
			"merchant_id": d.Cfg.PayHereMerchantID,
			"return_url":  d.Cfg.PublicBaseURL + "/api/v1/payments/payhere/return?ticket=" + t.ID,
			"cancel_url":  d.Cfg.PublicBaseURL + "/api/v1/payments/payhere/return?cancelled=1&ticket=" + t.ID,
			"notify_url":  d.Cfg.PublicBaseURL + "/api/v1/payments/payhere/notify",
			"order_id":    t.ID,
			"items":       fmt.Sprintf("Bus ticket %s seat %s (%s)", t.TicketNumber, t.SeatNumber, t.BusPlateNumber),
			"currency":    "LKR",
			"amount":      amt,
			"first_name":  t.PassengerName,
			"last_name":   "-",
			"email":       email,
			"phone":       phone,
			"address":     "-",
			"city":        "Colombo",
			"country":     "Sri Lanka",
			"hash":        md5Upper(d.Cfg.PayHereMerchantID + t.ID + amt + "LKR" + md5Upper(d.Cfg.PayHereMerchantSecret)),
		}
		c.Header("Content-Type", "text/html; charset=utf-8")
		_ = checkoutTmpl.Execute(c.Writer, gin.H{"Action": action, "Fields": fields})
	})

	rg.GET("/payhere/return", func(c *gin.Context) {
		msg := "Payment submitted. You can return to the CityBus Go app - your ticket updates automatically."
		if c.Query("cancelled") == "1" {
			msg = "Payment cancelled. Your seat hold will be released shortly."
		}
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(http.StatusOK, `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><body style="font-family:sans-serif;text-align:center;padding-top:40px"><p>%s</p></body>`, template.HTMLEscapeString(msg))
	})

	// PayHere server-to-server callback (application/x-www-form-urlencoded).
	rg.POST("/payhere/notify", func(c *gin.Context) {
		if !d.Cfg.PayHereEnabled() {
			c.Status(http.StatusNotFound)
			return
		}
		merchant, order := c.PostForm("merchant_id"), c.PostForm("order_id")
		amt, cur, code := c.PostForm("payhere_amount"), c.PostForm("payhere_currency"), c.PostForm("status_code")
		expected := md5Upper(merchant + order + amt + cur + code + md5Upper(d.Cfg.PayHereMerchantSecret))
		if merchant != d.Cfg.PayHereMerchantID || !hmac.Equal([]byte(expected), []byte(strings.ToUpper(c.PostForm("md5sig")))) {
			log.Printf("[PayHere] rejected notify for %s: bad signature", order)
			c.Status(http.StatusBadRequest)
			return
		}
		t, err := tickets.Load(d.DB, order)
		if err != nil {
			c.Status(http.StatusNotFound)
			return
		}
		if amt != amount(t.Fare) || cur != "LKR" {
			log.Printf("[PayHere] amount mismatch for %s: got %s %s want %s LKR", order, amt, cur, amount(t.Fare))
			c.Status(http.StatusBadRequest)
			return
		}
		switch code {
		case "2":
			if err := markPaid(d, t, "payhere", c.PostForm("payment_id")); err != nil {
				c.Status(http.StatusInternalServerError)
				return
			}
		case "-1", "-2", "-3":
			_, _ = d.DB.Exec(`INSERT INTO payments (id, ticket_id, provider, provider_ref, amount, status) VALUES (?, ?, 'payhere', ?, ?, 'failed')`,
				app.NewID("pay"), t.ID, c.PostForm("payment_id"), t.Fare)
			_ = tickets.Close(d, t.ID, "cancelled")
		}
		c.Status(http.StatusOK)
	})

	// Demo-only payment used when PayHere merchant credentials are not configured.
	rg.POST("/simulate", d.Auth(app.RolePassenger), func(c *gin.Context) {
		if d.Cfg.PayHereEnabled() {
			app.Fail(c, http.StatusNotFound, "simulated payments are disabled when PayHere is configured")
			return
		}
		var req struct {
			TicketID string `json:"ticket_id" binding:"required"`
		}
		if err := c.ShouldBindJSON(&req); err != nil {
			app.Fail(c, http.StatusBadRequest, err.Error())
			return
		}
		t, err := tickets.Load(d.DB, req.TicketID)
		if err != nil {
			app.DBError(c, err, "ticket")
			return
		}
		if t.PassengerID == nil || *t.PassengerID != app.User(c).UserID {
			app.Fail(c, http.StatusForbidden, "not your ticket")
			return
		}
		if t.PaymentStatus != "pending" || t.Status != "active" {
			app.Fail(c, http.StatusConflict, "ticket is not awaiting payment")
			return
		}
		if err := markPaid(d, t, "simulated", "SIM-"+t.TicketNumber); err != nil {
			app.DBError(c, err, "payment")
			return
		}
		t, _ = tickets.Load(d.DB, t.ID)
		c.JSON(http.StatusOK, t)
	})
}

func markPaid(d *app.Deps, t *tickets.Ticket, provider, ref string) error {
	tx, err := d.DB.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	res, err := tx.Exec(`UPDATE tickets SET payment_status='paid' WHERE id=? AND payment_status='pending' AND status='active'`, t.ID)
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return nil // already processed (PayHere may notify more than once)
	}
	if _, err := tx.Exec(`INSERT INTO payments (id, ticket_id, provider, provider_ref, amount, status) VALUES (?, ?, ?, ?, ?, 'success')`,
		app.NewID("pay"), t.ID, provider, ref, t.Fare); err != nil {
		return err
	}
	if err := tx.Commit(); err != nil {
		return err
	}
	d.Hub.BroadcastBus(t.BusID, gin.H{"type": "ticket_paid", "bus_id": t.BusID, "ticket_id": t.ID, "seat_number": t.SeatNumber})
	return nil
}
