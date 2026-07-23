#!/usr/bin/env python3
# -----------------------------------------------------------------------
# alu_uart_gui.py
#
# Desktop GUI for the alu_uart_system.v FPGA design.
#
# Protocol (must match alu_uart_system.v exactly):
#   TX to FPGA (9 bytes):
#     A[31:24] A[23:16] A[15:8] A[7:0]
#     B[31:24] B[23:16] B[15:8] B[7:0]
#     { opcode[3:0], cin, 3'b000 }
#
#   RX from FPGA (5 bytes):
#     result[31:24] result[23:16] result[15:8] result[7:0]
#     { 4'b0000, C, N, V, Z }
#
# Requires: pyserial   ->   pip install pyserial
# -----------------------------------------------------------------------

import sys
import struct
import threading
import queue
import time
from datetime import datetime

import tkinter as tk
from tkinter import ttk, messagebox

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("pyserial is required. Install it with:  pip install pyserial")
    sys.exit(1)


# -------------------------------------------------------------------
# Optional: name your opcodes here for display purposes only.
# This has no effect on the bytes sent -- purely cosmetic in the GUI.
# Edit to match your Control Signal Table.
# -------------------------------------------------------------------
OPCODE_NAMES = {
    0x0: "ADD",
    0x1: "SUB",
    0x2: "AND",
    0x3: "OR",
    0x4: "XOR",
    0x5: "NOT A",
    0x6: "SHL",
    0x7: "SHR",
    0x8: "ROL",
    0x9: "ROR",
    0xA: "CMP EQ",
    0xB: "CMP GT",
    0xC: "CMP LT",
    0xD: "-",
    0xE: "-",
    0xF: "-",
}


def parse_int(text, bits=32):
    """Accepts decimal or 0x-prefixed hex, returns int masked to `bits`."""
    text = text.strip()
    if text == "":
        raise ValueError("empty field")
    val = int(text, 16) if text.lower().startswith("0x") else int(text, 10)
    mask = (1 << bits) - 1
    if val < 0 or val > mask:
        raise ValueError(f"value out of range for {bits}-bit field: {text}")
    return val & mask


class AluUartGUI(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("FPGA ALU - UART Control Panel")
        self.geometry("880x620")
        self.resizable(True, True)

        self.ser = None
        self.rx_queue = queue.Queue()  # worker thread -> GUI thread messages
        self.busy = False

        self._build_ui()
        self._refresh_ports()
        self.after(50, self._poll_queue)

    # -----------------------------------------------------------
    # UI construction
    # -----------------------------------------------------------
    def _build_ui(self):
        pad = {"padx": 6, "pady": 4}

        # ---------------- Connection bar ----------------
        conn = ttk.LabelFrame(self, text="Connection")
        conn.pack(fill="x", padx=10, pady=8)

        ttk.Label(conn, text="Port:").grid(row=0, column=0, **pad)
        self.port_var = tk.StringVar()
        self.port_combo = ttk.Combobox(conn, textvariable=self.port_var, width=18, state="readonly")
        self.port_combo.grid(row=0, column=1, **pad)

        ttk.Button(conn, text="Refresh", command=self._refresh_ports).grid(row=0, column=2, **pad)

        ttk.Label(conn, text="Baud:").grid(row=0, column=3, **pad)
        self.baud_var = tk.StringVar(value="115200")
        baud_combo = ttk.Combobox(
            conn, textvariable=self.baud_var, width=10, state="readonly",
            values=["9600", "19200", "38400", "57600", "115200"]
        )
        baud_combo.grid(row=0, column=4, **pad)

        self.connect_btn = ttk.Button(conn, text="Connect", command=self._toggle_connect)
        self.connect_btn.grid(row=0, column=5, **pad)

        self.status_var = tk.StringVar(value="Disconnected")
        self.status_lbl = ttk.Label(conn, textvariable=self.status_var, foreground="red")
        self.status_lbl.grid(row=0, column=6, **pad)

        # ---------------- Input panel ----------------
        inp = ttk.LabelFrame(self, text="Transaction Input")
        inp.pack(fill="x", padx=10, pady=8)

        ttk.Label(inp, text="A (dec or 0x..):").grid(row=0, column=0, sticky="e", **pad)
        self.a_var = tk.StringVar(value="0x0000000A")
        ttk.Entry(inp, textvariable=self.a_var, width=16).grid(row=0, column=1, **pad)

        ttk.Label(inp, text="B (dec or 0x..):").grid(row=0, column=2, sticky="e", **pad)
        self.b_var = tk.StringVar(value="0x00000005")
        ttk.Entry(inp, textvariable=self.b_var, width=16).grid(row=0, column=3, **pad)

        ttk.Label(inp, text="Opcode:").grid(row=0, column=4, sticky="e", **pad)
        self.opcode_var = tk.StringVar()
        opcode_values = [f"0x{k:X}  ({v})" for k, v in OPCODE_NAMES.items()]
        self.opcode_combo = ttk.Combobox(inp, values=opcode_values, width=14, state="readonly")
        self.opcode_combo.current(0)
        self.opcode_combo.grid(row=0, column=5, **pad)

        self.cin_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(inp, text="Cin", variable=self.cin_var).grid(row=0, column=6, **pad)

        self.send_btn = ttk.Button(inp, text="Send", command=self._on_send)
        self.send_btn.grid(row=0, column=7, **pad)

        # ---------------- Result panel ----------------
        res = ttk.LabelFrame(self, text="Result")
        res.pack(fill="x", padx=10, pady=8)

        ttk.Label(res, text="Hex:").grid(row=0, column=0, sticky="e", **pad)
        self.res_hex_var = tk.StringVar(value="--")
        ttk.Label(res, textvariable=self.res_hex_var, font=("Consolas", 12, "bold")).grid(row=0, column=1, sticky="w", **pad)

        ttk.Label(res, text="Decimal:").grid(row=0, column=2, sticky="e", **pad)
        self.res_dec_var = tk.StringVar(value="--")
        ttk.Label(res, textvariable=self.res_dec_var, font=("Consolas", 12, "bold")).grid(row=0, column=3, sticky="w", **pad)

        ttk.Label(res, text="Binary:").grid(row=1, column=0, sticky="e", **pad)
        self.res_bin_var = tk.StringVar(value="--")
        ttk.Label(res, textvariable=self.res_bin_var, font=("Consolas", 9)).grid(row=1, column=1, columnspan=3, sticky="w", **pad)

        flagbar = ttk.Frame(res)
        flagbar.grid(row=0, column=4, rowspan=2, padx=20)
        self.flag_labels = {}
        for i, name in enumerate(["C", "N", "V", "Z"]):
            f = ttk.Label(flagbar, text=name, width=4, anchor="center",
                          font=("Consolas", 11, "bold"), background="#cccccc")
            f.grid(row=0, column=i, padx=3, ipady=4)
            self.flag_labels[name] = f

        # ---------------- History table ----------------
        hist = ttk.LabelFrame(self, text="Transaction History")
        hist.pack(fill="both", expand=True, padx=10, pady=8)

        cols = ("time", "a", "b", "op", "cin", "result", "c", "n", "v", "z")
        self.tree = ttk.Treeview(hist, columns=cols, show="headings", height=8)
        widths = {"time": 90, "a": 110, "b": 110, "op": 70, "cin": 40,
                  "result": 110, "c": 30, "n": 30, "v": 30, "z": 30}
        headers = {"time": "Time", "a": "A", "b": "B", "op": "Op", "cin": "Cin",
                   "result": "Result", "c": "C", "n": "N", "v": "V", "z": "Z"}
        for c in cols:
            self.tree.heading(c, text=headers[c])
            self.tree.column(c, width=widths[c], anchor="center")
        self.tree.pack(fill="both", expand=True, side="left")

        scroll = ttk.Scrollbar(hist, orient="vertical", command=self.tree.yview)
        scroll.pack(fill="y", side="right")
        self.tree.configure(yscrollcommand=scroll.set)

        # ---------------- Raw log ----------------
        logf = ttk.LabelFrame(self, text="Raw TX/RX Log")
        logf.pack(fill="both", expand=True, padx=10, pady=8)

        self.log_text = tk.Text(logf, height=6, font=("Consolas", 9), state="disabled")
        self.log_text.pack(fill="both", expand=True, side="left")
        logscroll = ttk.Scrollbar(logf, orient="vertical", command=self.log_text.yview)
        logscroll.pack(fill="y", side="right")
        self.log_text.configure(yscrollcommand=logscroll.set)

        ttk.Button(self, text="Clear Log", command=self._clear_log).pack(pady=(0, 8))

    # -----------------------------------------------------------
    # Serial connection handling
    # -----------------------------------------------------------
    def _refresh_ports(self):
        ports = [p.device for p in serial.tools.list_ports.comports()]
        self.port_combo["values"] = ports
        if ports and not self.port_var.get():
            self.port_combo.current(0)

    def _toggle_connect(self):
        if self.ser is not None and self.ser.is_open:
            self.ser.close()
            self.ser = None
            self.status_var.set("Disconnected")
            self.status_lbl.configure(foreground="red")
            self.connect_btn.configure(text="Connect")
            return

        port = self.port_var.get()
        if not port:
            messagebox.showerror("No port selected", "Choose a serial port first.")
            return
        try:
            self.ser = serial.Serial(port, int(self.baud_var.get()), timeout=2)
        except serial.SerialException as e:
            messagebox.showerror("Connection failed", str(e))
            self.ser = None
            return

        self.status_var.set(f"Connected: {port} @ {self.baud_var.get()} baud")
        self.status_lbl.configure(foreground="green")
        self.connect_btn.configure(text="Disconnect")

    # -----------------------------------------------------------
    # Send / receive (worker thread does the blocking I/O)
    # -----------------------------------------------------------
    def _on_send(self):
        if self.busy:
            return
        if self.ser is None or not self.ser.is_open:
            messagebox.showerror("Not connected", "Connect to a serial port first.")
            return

        try:
            a_val = parse_int(self.a_var.get(), 32)
            b_val = parse_int(self.b_var.get(), 32)
        except ValueError as e:
            messagebox.showerror("Invalid input", str(e))
            return

        opcode = self.opcode_combo.current()  # index 0-15 matches OPCODE_NAMES order
        cin = 1 if self.cin_var.get() else 0

        byte9 = ((opcode & 0xF) << 4) | ((cin & 0x1) << 3)
        packet = struct.pack(">IIB", a_val, b_val, byte9)

        self._log(f"TX -> {packet.hex(' ')}")

        self.busy = True
        self.send_btn.configure(state="disabled")
        threading.Thread(
            target=self._worker_send_recv,
            args=(packet, a_val, b_val, opcode, cin),
            daemon=True
        ).start()

    def _worker_send_recv(self, packet, a_val, b_val, opcode, cin):
        """Runs on a background thread: never touch Tk widgets here directly."""
        try:
            self.ser.reset_input_buffer()
            self.ser.write(packet)

            response = self.ser.read(5)  # blocks up to `timeout` seconds
            if len(response) != 5:
                self.rx_queue.put(("error", f"Timeout / short read: got {len(response)} of 5 bytes"))
                return

            result = struct.unpack(">I", response[0:4])[0]
            flag_byte = response[4]
            flags = {
                "C": (flag_byte >> 3) & 1,
                "N": (flag_byte >> 2) & 1,
                "V": (flag_byte >> 1) & 1,
                "Z": (flag_byte >> 0) & 1,
            }
            self.rx_queue.put(("ok", {
                "a": a_val, "b": b_val, "opcode": opcode, "cin": cin,
                "result": result, "flags": flags,
                "raw": response,
            }))
        except serial.SerialException as e:
            self.rx_queue.put(("error", f"Serial error: {e}"))

    # -----------------------------------------------------------
    # GUI-thread queue polling (safe place to update widgets)
    # -----------------------------------------------------------
    def _poll_queue(self):
        try:
            while True:
                kind, payload = self.rx_queue.get_nowait()
                if kind == "ok":
                    self._handle_result(payload)
                else:
                    self._log(f"ERROR: {payload}")
                    messagebox.showerror("Transaction failed", payload)
                self.busy = False
                self.send_btn.configure(state="normal")
        except queue.Empty:
            pass
        self.after(50, self._poll_queue)

    def _handle_result(self, data):
        result = data["result"]
        flags = data["flags"]

        self._log(f"RX <- {data['raw'].hex(' ')}")

        self.res_hex_var.set(f"0x{result:08X}")
        self.res_dec_var.set(str(result))
        self.res_bin_var.set(format(result, "032b"))

        for name, lbl in self.flag_labels.items():
            on = flags[name] == 1
            lbl.configure(background="#4caf50" if on else "#cccccc",
                          foreground="white" if on else "black")

        op_name = OPCODE_NAMES.get(data["opcode"], "?")
        self.tree.insert("", 0, values=(
            datetime.now().strftime("%H:%M:%S"),
            f"0x{data['a']:08X}",
            f"0x{data['b']:08X}",
            f"0x{data['opcode']:X} {op_name}",
            data["cin"],
            f"0x{result:08X}",
            flags["C"], flags["N"], flags["V"], flags["Z"],
        ))

    # -----------------------------------------------------------
    # Logging helpers
    # -----------------------------------------------------------
    def _log(self, msg):
        ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        self.log_text.configure(state="normal")
        self.log_text.insert("end", f"[{ts}] {msg}\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def _clear_log(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")

    def on_close(self):
        if self.ser is not None and self.ser.is_open:
            self.ser.close()
        self.destroy()


if __name__ == "__main__":
    app = AluUartGUI()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()
