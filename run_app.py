import tkinter as tk
from tkinter import ttk, messagebox
import random
from datetime import datetime

class CityBusGoApp:
    def __init__(self, root):
        self.root = root
        self.root.title("CityBus Go — Mobile Simulator")
        self.root.geometry("420x780")
        self.root.resizable(False, False)
        self.root.configure(bg="#1E88E5")

        self.current_user = None
        self.current_role = "passenger"
        self.selected_bus = "WP-ND-1024"
        self.selected_seat = None

        # Seed data
        self.seats_db = {}
        for s in range(1, 41):
            s_num = f"{s:02d}"
            # pre-occupy a few seats
            is_taken = s in [3, 4, 7, 8, 12, 15]
            self.seats_db[s_num] = {
                "status": "taken" if is_taken else "available",
                "booked_by": "Walk-in" if is_taken else None
            }

        self.main_container = tk.Frame(self.root, bg="#F5F7FA")
        self.main_container.pack(fill="both", expand=True, padx=8, pady=8)

        self.show_login_screen()

    def clear_container(self):
        for widget in self.main_container.winfo_children():
            widget.destroy()

    # --- 1. LOGIN SCREEN ---
    def show_login_screen(self):
        self.clear_container()

        header = tk.Frame(self.main_container, bg="#1E88E5", height=60)
        header.pack(fill="x")
        tk.Label(header, text="CityBus Go", font=("Segoe UI", 18, "bold"), fg="white", bg="#1E88E5").pack(pady=12)

        content = tk.Frame(self.main_container, bg="#F5F7FA", padx=24, pady=30)
        content.pack(fill="both", expand=True)

        tk.Label(content, text="🚌", font=("Segoe UI", 48), bg="#F5F7FA").pack()
        tk.Label(content, text="Real-Time Bus Ticketing", font=("Segoe UI", 14, "bold"), fg="#0D47A1", bg="#F5F7FA").pack()
        tk.Label(content, text="Select your mode to test the system:", font=("Segoe UI", 9), fg="#666", bg="#F5F7FA").pack(pady=10)

        tk.Label(content, text="User Role:", font=("Segoe UI", 10, "bold"), bg="#F5F7FA").pack(anchor="w", pady=(15, 2))
        self.role_var = tk.StringVar(value="passenger")
        r_frame = tk.Frame(content, bg="#F5F7FA")
        r_frame.pack(fill="x", pady=4)
        tk.Radiobutton(r_frame, text="Passenger Mode", variable=self.role_var, value="passenger", bg="#F5F7FA", font=("Segoe UI", 10)).pack(anchor="w")
        tk.Radiobutton(r_frame, text="Conductor Mode", variable=self.role_var, value="conductor", bg="#F5F7FA", font=("Segoe UI", 10)).pack(anchor="w")

        tk.Label(content, text="Name:", font=("Segoe UI", 10, "bold"), bg="#F5F7FA").pack(anchor="w", pady=(10, 2))
        self.name_entry = tk.Entry(content, font=("Segoe UI", 11))
        self.name_entry.insert(0, "Alex Fernando")
        self.name_entry.pack(fill="x", pady=4)

        btn_login = tk.Button(content, text="LOGIN TO SYSTEM", bg="#1E88E5", fg="white", font=("Segoe UI", 11, "bold"),
                              relief="flat", pady=10, command=self.do_login)
        btn_login.pack(fill="x", pady=25)

    def do_login(self):
        self.current_user = self.name_entry.get().strip() or "User"
        self.current_role = self.role_var.get()
        if self.current_role == "passenger":
            self.show_passenger_home()
        else:
            self.show_seat_map()

    # --- 2. PASSENGER HOME SCREEN ---
    def show_passenger_home(self):
        self.clear_container()

        header = tk.Frame(self.main_container, bg="#1E88E5", height=50)
        header.pack(fill="x")
        tk.Label(header, text="CityBus Go — Passenger", font=("Segoe UI", 13, "bold"), fg="white", bg="#1E88E5").pack(side="left", padx=12, pady=10)
        tk.Button(header, text="Logout", bg="#0D47A1", fg="white", font=("Segoe UI", 9), relief="flat", command=self.show_login_screen).pack(side="right", padx=10)

        content = tk.Frame(self.main_container, bg="#F5F7FA", padx=16, pady=16)
        content.pack(fill="both", expand=True)

        user_card = tk.Frame(content, bg="#E3F2FD", padx=12, pady=10)
        user_card.pack(fill="x", pady=(0, 15))
        tk.Label(user_card, text=f"Welcome, {self.current_user}!", font=("Segoe UI", 11, "bold"), fg="#0D47A1", bg="#E3F2FD").pack(anchor="w")
        tk.Label(user_card, text="Role: Passenger (Search & Book Seats)", font=("Segoe UI", 9), fg="#555", bg="#E3F2FD").pack(anchor="w")

        tk.Label(content, text="Find Bus by Number Plate:", font=("Segoe UI", 10, "bold"), bg="#F5F7FA").pack(anchor="w")
        self.plate_entry = tk.Entry(content, font=("Segoe UI", 11))
        self.plate_entry.insert(0, "WP-ND-1024")
        self.plate_entry.pack(fill="x", pady=6)

        tk.Button(content, text="VIEW BUS SEAT MAP", bg="#1E88E5", fg="white", font=("Segoe UI", 10, "bold"),
                  relief="flat", pady=8, command=self.show_seat_map).pack(fill="x", pady=6)

        tk.Label(content, text="Active Routes:", font=("Segoe UI", 10, "bold"), bg="#F5F7FA").pack(anchor="w", pady=(15, 6))
        
        bus1 = tk.Frame(content, bg="white", padx=10, pady=8, relief="solid", bd=1)
        bus1.pack(fill="x", pady=4)
        tk.Label(bus1, text="Route 138: Colombo Fort ➔ Kottawa", font=("Segoe UI", 9, "bold"), bg="white").pack(anchor="w")
        tk.Label(bus1, text="Bus: WP-ND-1024 • Fare: Rs. 150", font=("Segoe UI", 8), fg="#666", bg="white").pack(anchor="w")

        bus2 = tk.Frame(content, bg="white", padx=10, pady=8, relief="solid", bd=1)
        bus2.pack(fill="x", pady=4)
        tk.Label(bus2, text="Route 120: Pettah ➔ Horana", font=("Segoe UI", 9, "bold"), bg="white").pack(anchor="w")
        tk.Label(bus2, text="Bus: WP-NA-9081 • Fare: Rs. 220", font=("Segoe UI", 8), fg="#666", bg="white").pack(anchor="w")

        tk.Button(content, text="📡 Open GPS Diagnostics (RTBT-16)", bg="#00897B", fg="white", font=("Segoe UI", 10, "bold"),
                  relief="flat", pady=8, command=self.show_gps_screen).pack(fill="x", side="bottom", pady=10)

    # --- 3. SEAT MAP SCREEN ---
    def show_seat_map(self):
        self.clear_container()

        role_title = "Passenger" if self.current_role == "passenger" else "Conductor"
        header = tk.Frame(self.main_container, bg="#0D47A1" if self.current_role == "conductor" else "#1E88E5", height=50)
        header.pack(fill="x")
        tk.Label(header, text=f"Seat Map ({role_title})", font=("Segoe UI", 12, "bold"), fg="white", bg=header["bg"]).pack(side="left", padx=10, pady=10)
        back_cmd = self.show_passenger_home if self.current_role == "passenger" else self.show_login_screen
        tk.Button(header, text="Back", bg="white", fg="#0D47A1", font=("Segoe UI", 9), relief="flat", command=back_cmd).pack(side="right", padx=10)

        content = tk.Frame(self.main_container, bg="#F5F7FA", padx=12, pady=10)
        content.pack(fill="both", expand=True)

        info_bar = tk.Frame(content, bg="#ECEFF1", padx=10, pady=6)
        info_bar.pack(fill="x", pady=(0, 6))
        tk.Label(info_bar, text="Bus: WP-ND-1024  •  Route: 138 (Fare: Rs. 150)", font=("Segoe UI", 9, "bold"), bg="#ECEFF1").pack(anchor="w")

        # Legend
        leg_bar = tk.Frame(content, bg="#F5F7FA")
        leg_bar.pack(fill="x", pady=4)
        tk.Label(leg_bar, text="■ Green = Free", fg="#2E7D32", font=("Segoe UI", 9, "bold"), bg="#F5F7FA").pack(side="left", padx=4)
        tk.Label(leg_bar, text="■ Red = Taken", fg="#C62828", font=("Segoe UI", 9, "bold"), bg="#F5F7FA").pack(side="left", padx=4)
        tk.Label(leg_bar, text="■ Blue = Selected", fg="#0288D1", font=("Segoe UI", 9, "bold"), bg="#F5F7FA").pack(side="left", padx=4)

        # Seat Grid Scrollable Area
        grid_frame = tk.Frame(content, bg="white", relief="solid", bd=1, padx=10, pady=10)
        grid_frame.pack(fill="both", expand=True)
        tk.Label(grid_frame, text="🚌 FRONT / DRIVER", font=("Segoe UI", 9, "bold"), fg="#555", bg="white").pack(anchor="e", pady=(0, 6))

        self.seat_buttons = {}
        rows_container = tk.Frame(grid_frame, bg="white")
        rows_container.pack()

        for r in range(10):
            row_f = tk.Frame(rows_container, bg="white")
            row_f.pack(pady=2)

            for c in range(4):
                seat_idx = r * 4 + c + 1
                s_num = f"{seat_idx:02d}"
                status = self.seats_db[s_num]["status"]
                bg_col = "#E53935" if status == "taken" else "#43A047"

                btn = tk.Button(row_f, text=s_num, width=4, height=1, bg=bg_col, fg="white", font=("Segoe UI", 8, "bold"),
                                relief="flat", command=lambda n=s_num: self.select_seat(n))
                btn.pack(side="left", padx=2)
                self.seat_buttons[s_num] = btn

                if c == 1:
                    tk.Label(row_f, text="   ", bg="white").pack(side="left")

        # Booking Action Bar
        self.action_frame = tk.Frame(content, bg="#E3F2FD", padx=10, pady=8)
        self.action_frame.pack(fill="x", pady=6)
        self.action_label = tk.Label(self.action_frame, text="Select a green seat to book", font=("Segoe UI", 9, "bold"), bg="#E3F2FD", fg="#0D47A1")
        self.action_label.pack(side="left")
        self.confirm_btn = tk.Button(self.action_frame, text="CONFIRM BOOKING", bg="#1E88E5", fg="white", font=("Segoe UI", 9, "bold"),
                                     relief="flat", state="disabled", command=self.confirm_seat_booking)
        self.confirm_btn.pack(side="right")

    def select_seat(self, s_num):
        if self.seats_db[s_num]["status"] == "taken":
            messagebox.showwarning("Seat Occupied", f"Seat #{s_num} is already occupied by {self.seats_db[s_num]['booked_by']}!")
            return

        # Restore previous selected seat
        if self.selected_seat and self.seats_db[self.selected_seat]["status"] == "available":
            self.seat_buttons[self.selected_seat].configure(bg="#43A047")

        self.selected_seat = s_num
        self.seat_buttons[s_num].configure(bg="#0288D1")
        action_text = "Issue Cash Ticket" if self.current_role == "conductor" else "Book Seat"
        self.action_label.config(text=f"Seat #{s_num} • Rs. 150")
        self.confirm_btn.config(state="normal", text=f"{action_text} (#{s_num})")

    def confirm_seat_booking(self):
        if not self.selected_seat:
            return

        # Atomic transaction check
        if self.seats_db[self.selected_seat]["status"] == "taken":
            messagebox.showerror("Conflict", "This seat was just reserved by another passenger!")
            self.show_seat_map()
            return

        self.seats_db[self.selected_seat]["status"] = "taken"
        self.seats_db[self.selected_seat]["booked_by"] = self.current_user

        self.show_ticket_screen(self.selected_seat)

    # --- 4. TICKET CONFIRMATION SCREEN ---
    def show_ticket_screen(self, seat_num):
        self.clear_container()

        header = tk.Frame(self.main_container, bg="#43A047", height=50)
        header.pack(fill="x")
        tk.Label(header, text="✓ TICKET ISSUED", font=("Segoe UI", 12, "bold"), fg="white", bg="#43A047").pack(pady=10)

        content = tk.Frame(self.main_container, bg="#F5F7FA", padx=20, pady=20)
        content.pack(fill="both", expand=True)

        card = tk.Frame(content, bg="#FFF8E1", relief="solid", bd=1, padx=16, pady=16)
        card.pack(fill="x")

        tkt_id = f"TKT-{random.randint(100000, 999999)}"
        tk.Label(card, text="DIGITAL BOARDING PASS", font=("Segoe UI", 11, "bold"), fg="#FF8F00", bg="#FFF8E1").pack()
        tk.Label(card, text=tkt_id, font=("Segoe UI", 9), fg="#666", bg="#FFF8E1").pack(pady=2)

        qr_box = tk.Label(card, text="[ QR CODE VALIDATED ]\n■■■■■■■■■■■■■\n■■■■■■■■■■■■■", font=("Courier", 10, "bold"),
                          bg="#37474F", fg="white", padx=10, pady=10)
        qr_box.pack(pady=10)

        details = [
            f"Passenger: {self.current_user}",
            f"Bus Plate: {self.selected_bus}",
            f"Seat: #{seat_num}",
            "Route: 138 (Colombo Fort - Kottawa)",
            "Fare: Rs. 150.00 (PAID)",
            f"Issued: {datetime.now().strftime('%H:%M:%S')}"
        ]
        for d in details:
            tk.Label(card, text=d, font=("Segoe UI", 9), bg="#FFF8E1", anchor="w").pack(fill="x", pady=1)

        tk.Button(content, text="BOOK ANOTHER SEAT", bg="#1E88E5", fg="white", font=("Segoe UI", 10, "bold"),
                  relief="flat", pady=10, command=self.show_seat_map).pack(fill="x", pady=20)

    # --- 5. GPS DIAGNOSTICS SCREEN ---
    def show_gps_screen(self):
        self.clear_container()

        header = tk.Frame(self.main_container, bg="#00897B", height=50)
        header.pack(fill="x")
        tk.Label(header, text="GPS Diagnostics (RTBT-16)", font=("Segoe UI", 12, "bold"), fg="white", bg="#00897B").pack(side="left", padx=10, pady=10)
        tk.Button(header, text="Back", bg="white", fg="#00897B", font=("Segoe UI", 9), relief="flat", command=self.show_passenger_home).pack(side="right", padx=10)

        content = tk.Frame(self.main_container, bg="#F5F7FA", padx=16, pady=20)
        content.pack(fill="both", expand=True)

        card = tk.Frame(content, bg="#ECEFF1", padx=14, pady=14, relief="solid", bd=1)
        card.pack(fill="x")

        tk.Label(card, text="TELEMETRY STREAM: ACTIVE", font=("Segoe UI", 10, "bold"), fg="#2E7D32", bg="#ECEFF1").pack(anchor="w")
        lat = f"{6.927079 + random.uniform(-0.002, 0.002):.6f}"
        lng = f"{79.861244 + random.uniform(-0.002, 0.002):.6f}"
        acc = f"{random.uniform(2.5, 4.5):.1f} m"
        spd = f"{random.uniform(25.0, 42.0):.1f} km/h"

        tk.Label(card, text=f"Latitude:   {lat}", font=("Courier", 10), bg="#ECEFF1").pack(anchor="w", pady=2)
        tk.Label(card, text=f"Longitude:  {lng}", font=("Courier", 10), bg="#ECEFF1").pack(anchor="w", pady=2)
        tk.Label(card, text=f"Accuracy:   {acc}", font=("Courier", 10), bg="#ECEFF1").pack(anchor="w", pady=2)
        tk.Label(card, text=f"Speed:      {spd}", font=("Courier", 10), bg="#ECEFF1").pack(anchor="w", pady=2)
        tk.Label(card, text=f"Time:       {datetime.now().strftime('%H:%M:%S')}", font=("Courier", 10), bg="#ECEFF1").pack(anchor="w", pady=2)

        tk.Button(content, text="REFRESH FIX PING", bg="#00897B", fg="white", font=("Segoe UI", 10, "bold"),
                  relief="flat", pady=8, command=self.show_gps_screen).pack(fill="x", pady=15)

if __name__ == "__main__":
    root = tk.Tk()
    app = CityBusGoApp(root)
    root.mainloop()

