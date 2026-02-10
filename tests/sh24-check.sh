curl -v \
     -X POST https://admin.qa3.sh24.org.uk/oauth/token \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "grant_type=client_credentials" \
     -d "client_id=APPLICATION UID HERE" \
     -d "client_secret=APPLICATION SECRET HERE" \
     -d "scope=order results"
