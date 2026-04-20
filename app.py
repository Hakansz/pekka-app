from flask import Flask, jsonify, request, render_template, session, redirect, url_for
import requests
import os

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "byt-mig-i-prod")

GLUETUN = os.environ.get("GLUETUN_URL", "http://192.168.1.173:8001")
AUTH    = ("hakan", "ronny")
PIN     = os.environ.get("PEKKA_PIN", "1234")

# ---------- Auth ----------

@app.before_request
def check_pin():
    open_paths = ["/login", "/static", "/countries.json"]
    if any(request.path.startswith(p) for p in open_paths):
        return
    if not session.get("ok"):
        return redirect(url_for("login"))

@app.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        if request.form.get("pin") == PIN:
            session["ok"] = True
            return redirect(url_for("index"))
        error = "Fel PIN-kod"
    return render_template("login.html", error=error)

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))

# ---------- Sidor ----------

@app.route("/")
def index():
    return render_template("index.html", status=vpn_status())

@app.route("/debug")
def debug():
    return render_template("debug.html", status=vpn_status(), gluetun=GLUETUN)

@app.route("/help")
def help():
    return render_template("help.html")

@app.route('/countries.json')
def countries():
    import json
    with open('countries.json') as f:
        return app.response_class(f.read(), mimetype='application/json')

# ---------- API ----------

@app.route("/api/status")
def api_status():
    return jsonify(vpn_status())

@app.route("/api/select/<country>", methods=["GET", "POST"])
def api_select(country):
    country = country.lower()
    try:
        if country == "sweden":
            # Sverige = VPN av, använd Ronnys exit
            r = requests.put(f"{GLUETUN}/v1/vpn/status",
                             json={"status": "stopped"}, auth=AUTH, timeout=5)
        else:
            # Sätt exit-land och starta VPN
            r = requests.put(f"{GLUETUN}/v1/vpn/settings",
                             json={"provider": {"name": "mullvad",
                                                "server_selection": {
                                                    "vpn": "wireguard",
                                                    "countries": [country.upper() if country in ["uk","usa"] else country]}}},
                             auth=AUTH, timeout=5)
            if r.status_code == 200:
                r = requests.put(f"{GLUETUN}/v1/vpn/status",
                                 json={"status": "running"}, auth=AUTH, timeout=5)

        if r.status_code == 200:
            return jsonify({"status": "ok", "vpn": country})
        else:
            return jsonify({"status": "error", "message": r.text}), 500

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# ---------- Hjälpfunktion ----------

def vpn_status():
    try:
        s  = requests.get(f"{GLUETUN}/v1/vpn/status",  auth=AUTH, timeout=3)
        ip = requests.get(f"{GLUETUN}/v1/publicip/ip", auth=AUTH, timeout=3)
        return {
            "vpn_status": s.json().get("status", "unknown"),
            "public_ip":  ip.json().get("public_ip", "?"),
            "country":    ip.json().get("country", "?"),
            "city":       ip.json().get("city", "?"),
        }
    except Exception as e:
        return {"vpn_status": "error", "public_ip": "?", "country": "?", "city": "?", "message": str(e)}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 5005)), debug=False)
