echo -n "PIN: "
read -s PIN
echo ""

result=$(curl -s -c /tmp/pekka.cookie -X POST http://localhost:5008/login -d "pin=$PIN" -w "%{http_code}" -o /dev/null)
if [ "$result" != "302" ]; then
  echo "❌ Fel PIN"
  exit 1
fi
echo "✅ Inloggad"

COUNTRIES=$(python3 -c "
import json
with open('countries.json') as f:
    countries = [c['val'] for c in json.load(f) if c['val']]
print(' '.join(countries))
")

for val in $COUNTRIES; do
  echo -n "🔄 $val ... "
  api_result=$(curl -s -b /tmp/pekka.cookie -X POST http://localhost:5008/api/select/$val)
  api_status=$(echo $api_result | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))")
  if [ "$api_status" != "ok" ]; then
    echo "❌ $(echo $api_result | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','?')[:80])")"
    exit 1
  fi
  OK=0
  echo -n "väntar"
  for i in $(seq 1 60); do
    sleep 1
    echo -n "."
    STATUS_JSON=$(curl -s -b /tmp/pekka.cookie http://localhost:5008/api/status)
    state=$(echo $STATUS_JSON | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('vpn_status','?'))")
    country=$(echo $STATUS_JSON | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('country','?'))")
    if [ "$val" = "sweden" ] && [ "$state" = "stopped" ]; then
      echo " ✅ VPN av"; OK=1; break
    elif [ "$val" != "sweden" ] && [ "$state" = "running" ] && [ "$country" != "?" ] && [ "$country" != "" ]; then
      echo " ✅ $country (${i}s)"; OK=1; break
    fi
  done
  if [ $OK -eq 0 ]; then
    echo " ⚠️ Timeout – avbryter"; exit 1
  fi
done

echo ""
echo "=== QA KLAR ✅ ==="
