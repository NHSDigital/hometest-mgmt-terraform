package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/rds"
	"github.com/aws/aws-sdk-go/service/rds/rdsutils"
	"github.com/aws/aws-sdk-go/service/secretsmanager"
	"github.com/aws/aws-sdk-go/service/sts"
	"github.com/jackc/pgx/v5"
	_ "github.com/lib/pq"
)

// RDS CA bundle for eu-west-2 (same as used by the TypeScript app lambdas).
// Source: https://truststore.pki.rds.amazonaws.com/eu-west-2/eu-west-2-bundle.pem
const rdsCACert = `-----BEGIN CERTIFICATE-----
MIICrjCCAjSgAwIBAgIRAKKPTYKln9L4NTx9dpZGUjowCgYIKoZIzj0EAwMwgZYx
CzAJBgNVBAYTAlVTMSIwIAYDVQQKDBlBbWF6b24gV2ViIFNlcnZpY2VzLCBJbmMu
MRMwEQYDVQQLDApBbWF6b24gUkRTMQswCQYDVQQIDAJXQTEvMC0GA1UEAwwmQW1h
em9uIFJEUyBldS13ZXN0LTIgUm9vdCBDQSBFQ0MzODQgRzExEDAOBgNVBAcMB1Nl
YXR0bGUwIBcNMjEwNTIxMjI1NTIxWhgPMjEyMTA1MjEyMzU1MjFaMIGWMQswCQYD
VQQGEwJVUzEiMCAGA1UECgwZQW1hem9uIFdlYiBTZXJ2aWNlcywgSW5jLjETMBEG
A1UECwwKQW1hem9uIFJEUzELMAkGA1UECAwCV0ExLzAtBgNVBAMMJkFtYXpvbiBS
RFMgZXUtd2VzdC0yIFJvb3QgQ0EgRUNDMzg0IEcxMRAwDgYDVQQHDAdTZWF0dGxl
MHYwEAYHKoZIzj0CAQYFK4EEACIDYgAE/owTReDvaRqdmbtTzXbyRmEpKCETNj6O
hZMKH0F8oU9Tmn8RU7kQQj6xUKEyjLPrFBN7c+26TvrVO1KmJAvbc8bVliiJZMbc
C0yV5PtJTalvlMZA1NnciZuhxaxrzlK1o0IwQDAPBgNVHRMBAf8EBTADAQH/MB0G
A1UdDgQWBBT4i5HaoHtrs7Mi8auLhMbKM1XevDAOBgNVHQ8BAf8EBAMCAYYwCgYI
KoZIzj0EAwMDaAAwZQIxAK9A+8/lFdX4XJKgfP+ZLy5ySXC2E0Spoy12Gv2GdUEZ
p1G7c1KbWVlyb1d6subzkQIwKyH0Naf/3usWfftkmq8SzagicKz5cGcEUaULq4tO
GzA/AMpr63IDBAqkZbMDTCmH
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIF/zCCA+egAwIBAgIRAMDk/F+rrhdn42SfE+ghPC8wDQYJKoZIhvcNAQEMBQAw
gZcxCzAJBgNVBAYTAlVTMSIwIAYDVQQKDBlBbWF6b24gV2ViIFNlcnZpY2VzLCBJ
bmMuMRMwEQYDVQQLDApBbWF6b24gUkRTMQswCQYDVQQIDAJXQTEwMC4GA1UEAwwn
QW1hem9uIFJEUyBldS13ZXN0LTIgUm9vdCBDQSBSU0E0MDk2IEcxMRAwDgYDVQQH
DAdTZWF0dGxlMCAXDTIxMDUyMTIyNTEyMloYDzIxMjEwNTIxMjM1MTIyWjCBlzEL
MAkGA1UEBhMCVVMxIjAgBgNVBAoMGUFtYXpvbiBXZWIgU2VydmljZXMsIEluYy4x
EzARBgNVBAsMCkFtYXpvbiBSRFMxCzAJBgNVBAgMAldBMTAwLgYDVQQDDCdBbWF6
b24gUkRTIGV1LXdlc3QtMiBSb290IENBIFJTQTQwOTYgRzExEDAOBgNVBAcMB1Nl
YXR0bGUwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC2twMALVg9vRVu
VNqsr6N8thmp3Dy8jEGTsm3GCQ+C5P2YcGlD/T/5icfWW84uF7Sx3ezcGlvsqFMf
Ukj9sQyqtz7qfFFugyy7pa/eH9f48kWFHLbQYm9GEgbYBIrWMp1cy3vyxuMCwQN4
DCncqU+yNpy0CprQJEha3PzY+3yJOjDQtc3zr99lyECCFJTDUucxHzyQvX89eL74
uh8la0lKH3v9wPpnEoftbrwmm5jHNFdzj7uXUHUJ41N7af7z7QUfghIRhlBDiKtx
5lYZemPCXajTc3ryDKUZC/b+B6ViXZmAeMdmQoPE0jwyEp/uaUcdp+FlUQwCfsBk
ayPFEApTWgPiku2isjdeTVmEgL8bJTDUZ6FYFR7ZHcYAsDzcwHgIu3GGEMVRS3Uf
ILmioiyly9vcK4Sa01ondARmsi/I0s7pWpKflaekyv5boJKD/xqwz9lGejmJHelf
8Od2TyqJScMpB7Q8c2ROxBwqwB72jMCEvYigB+Wnbb8RipliqNflIGx938FRCzKL
UQUBmNAznR/yRRL0wHf9UAE/8v9a09uZABeiznzOFAl/frHpgdAbC00LkFlnwwgX
g8YfEFlkp4fLx5B7LtoO6uVNFVimLxtwirpyKoj3G4M/kvSTux8bTw0heBCmWmKR
57MS6k7ODzbv+Kpeht2hqVZCNFMxoQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/
MB0GA1UdDgQWBBRuMnDhJjoj7DcKALj+HbxEqj3r6jAOBgNVHQ8BAf8EBAMCAYYw
DQYJKoZIhvcNAQEMBQADggIBALSnXfx72C3ldhBP5kY4Mo2DDaGQ8FGpTOOiD95d
0rf7I9LrsBGVqu/Nir+kqqP80PB70+Jy9fHFFigXwcPBX3MpKGxK8Cel7kVf8t1B
4YD6A6bqlzP+OUL0uGWfZpdpDxwMDI2Flt4NEldHgXWPjvN1VblEKs0+kPnKowyg
jhRMgBbD/y+8yg0fIcjXUDTAw/+INcp21gWaMukKQr/8HswqC1yoqW9in2ijQkpK
2RB9vcQ0/gXR0oJUbZQx0jn0OH8Agt7yfMAnJAdnHO4M3gjvlJLzIC5/4aGrRXZl
JoZKfJ2fZRnrFMi0nhAYDeInoS+Rwx+QzaBk6fX5VPyCj8foZ0nmqvuYoydzD8W5
mMlycgxFqS+DUmO+liWllQC4/MnVBlHGB1Cu3wTj5kgOvNs/k+FW3GXGzD3+rpv0
QTLuwSbMr+MbEThxrSZRSXTCQzKfehyC+WZejgLb+8ylLJUA10e62o7H9PvCrwj+
ZDVmN7qj6amzvndCP98sZfX7CFZPLfcBd4wVIjHsFjSNEwWHOiFyLPPG7cdolGKA
lOFvonvo4A1uRc13/zFeP0Xi5n5OZ2go8aOOeGYdI2vB2sgH9R2IASH/jHmr0gvY
0dfBCcfXNgrS0toq0LX/y+5KkKOxh52vEYsJLdhqrveuZhQnsFEm/mFwjRXkyO7c
2jpC
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIID/jCCAuagAwIBAgIQTDc+UgTRtYO7ZGTQ8UWKDDANBgkqhkiG9w0BAQsFADCB
lzELMAkGA1UEBhMCVVMxIjAgBgNVBAoMGUFtYXpvbiBXZWIgU2VydmljZXMsIElu
Yy4xEzARBgNVBAsMCkFtYXpvbiBSRFMxCzAJBgNVBAgMAldBMTAwLgYDVQQDDCdB
bWF6b24gUkRTIGV1LXdlc3QtMiBSb290IENBIFJTQTIwNDggRzExEDAOBgNVBAcM
B1NlYXR0bGUwIBcNMjEwNTIxMjI0NjI0WhgPMjA2MTA1MjEyMzQ2MjRaMIGXMQsw
CQYDVQQGEwJVUzEiMCAGA1UECgwZQW1hem9uIFdlYiBTZXJ2aWNlcywgSW5jLjET
MBEGA1UECwwKQW1hem9uIFJEUzELMAkGA1UECAwCV0ExMDAuBgNVBAMMJ0FtYXpv
biBSRFMgZXUtd2VzdC0yIFJvb3QgQ0EgUlNBMjA0OCBHMTEQMA4GA1UEBwwHU2Vh
dHRsZTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM1oGtthQ1YiVIC2
i4u4swMAGxAjc/BZp0yq0eP5ZQFaxnxs7zFAPabEWsrjeDzrRhdVO0h7zskrertP
gblGhfD20JfjvCHdP1RUhy/nzG+T+hn6Takan/GIgs8grlBMRHMgBYHW7tklhjaH
3F7LujhceAHhhgp6IOrpb6YTaTTaJbF3GTmkqxSJ3l1LtEoWz8Al/nL/Ftzxrtez
Vs6ebpvd7sw37sxmXBWX2OlvUrPCTmladw9OrllGXtCFw4YyLe3zozBlZ3cHzQ0q
lINhpRcajTMfZrsiGCkQtoJT+AqVJPS2sHjqsEH8yiySW9Jbq4zyMbM1yqQ2vnnx
MJgoYMcCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUaQG88UnV
JPTI+Pcti1P+q3H7pGYwDgYDVR0PAQH/BAQDAgGGMA0GCSqGSIb3DQEBCwUAA4IB
AQBAkgr75V0sEJimC6QRiTVWEuj2Khy7unjSfudbM6zumhXEU2/sUaVLiYy6cA/x
3v0laDle6T07x9g64j5YastE/4jbzrGgIINFlY0JnaYmR3KZEjgi1s1fkRRf3llL
PJm9u4Q1mbwAMQK/ZjLuuRcL3uRIHJek18nRqT5h43GB26qXyvJqeYYpYfIjL9+/
YiZAbSRRZG+Li23cmPWrbA1CJY121SB+WybCbysbOXzhD3Sl2KSZRwSw4p2HrFtV
1Prk0dOBtZxCG9luf87ultuDZpfS0w6oNBAMXocgswk24ylcADkkFxBWW+7BETn1
EpK+t1Lm37mU4sxtuha00XAi
-----END CERTIFICATE-----
`

type Response struct {
	Status      string            `json:"status"`
	Auth        string            `json:"auth"`
	User        string            `json:"user"`
	Schema      string            `json:"schema"`
	CallerARN   string            `json:"caller_arn,omitempty"`
	AccountID   string            `json:"account_id,omitempty"`
	TokenLength int               `json:"token_length,omitempty"`
	Tests       map[string]string `json:"tests"`
	Message     string            `json:"message,omitempty"`
}

func handler(ctx context.Context) (Response, error) {
	username := os.Getenv("DB_USERNAME")
	host := os.Getenv("DB_ADDRESS")
	port := os.Getenv("DB_PORT")
	dbname := os.Getenv("DB_NAME")
	schema := os.Getenv("DB_SCHEMA")
	region := os.Getenv("DB_REGION")
	masterSecretARN := os.Getenv("MASTER_SECRET_ARN")
	clusterID := os.Getenv("DB_CLUSTER_ID")
	_ = os.Getenv("APP_USER_SECRET_NAME")

	if region == "" {
		region = os.Getenv("AWS_REGION")
	}

	log.Printf("=== DB Auth Diagnostic Test v5 ===")
	log.Printf("Host:      %s", host)
	log.Printf("Port:      %s", port)
	log.Printf("User:      %s", username)
	log.Printf("DB:        %s", dbname)
	log.Printf("Schema:    %s", schema)
	log.Printf("Region:    %s", region)
	log.Printf("ClusterID: %s", clusterID)

	tests := make(map[string]string)

	sess, err := session.NewSession(&aws.Config{Region: aws.String(region)})
	if err != nil {
		return Response{Status: "FAIL", Message: fmt.Sprintf("AWS session failed: %s", err)}, nil
	}

	// --- Step 1: Who am I? ---
	log.Println("Step 1: STS GetCallerIdentity...")
	var callerARN, accountID string
	stsClient := sts.New(sess)
	identity, err := stsClient.GetCallerIdentity(&sts.GetCallerIdentityInput{})
	if err != nil {
		log.Printf("  FAIL: %s", err)
		tests["sts_identity"] = fmt.Sprintf("FAIL: %s", err)
	} else {
		callerARN = *identity.Arn
		accountID = *identity.Account
		tests["sts_identity"] = callerARN
		log.Printf("  ARN: %s", callerARN)
	}

	// --- Step 1b: Check IAM auth + engine version at the AWS API level ---
	log.Println("Step 1b: RDS DescribeDBClusters...")
	var clusterResourceID string
	if clusterID != "" {
		rdsClient := rds.New(sess)
		descOut, err := rdsClient.DescribeDBClusters(&rds.DescribeDBClustersInput{
			DBClusterIdentifier: aws.String(clusterID),
		})
		if err != nil {
			log.Printf("  FAIL: %s", err)
			tests["aws_iam_auth_enabled"] = fmt.Sprintf("FAIL: %s", err)
		} else if len(descOut.DBClusters) > 0 {
			cl := descOut.DBClusters[0]
			enabled := false
			if cl.IAMDatabaseAuthenticationEnabled != nil {
				enabled = *cl.IAMDatabaseAuthenticationEnabled
			}
			if cl.DbClusterResourceId != nil {
				clusterResourceID = *cl.DbClusterResourceId
			}
			engineVer := ""
			if cl.EngineVersion != nil {
				engineVer = *cl.EngineVersion
			}
			engine := ""
			if cl.Engine != nil {
				engine = *cl.Engine
			}
			tests["aws_iam_auth_enabled"] = fmt.Sprintf("%v", enabled)
			tests["cluster_resource_id"] = clusterResourceID
			tests["engine"] = fmt.Sprintf("%s %s", engine, engineVer)
			log.Printf("  IAMDatabaseAuthenticationEnabled: %v", enabled)
			log.Printf("  DbClusterResourceId: %s", clusterResourceID)
			log.Printf("  Engine: %s %s", engine, engineVer)
		}
	} else {
		tests["aws_iam_auth_enabled"] = "SKIPPED (no DB_CLUSTER_ID)"
	}

	// --- Step 2: Connect as master user to check DB state ---
	log.Println("Step 2: Connect as master user to check DB state...")
	if masterSecretARN != "" {
		masterPw, err := getSecretPassword(sess, masterSecretARN)
		if err != nil {
			log.Printf("  FAIL (secret): %s", err)
			tests["master_connect"] = fmt.Sprintf("FAIL (secret): %s", err)
		} else {
			masterUser := os.Getenv("MASTER_USERNAME")
			if masterUser == "" {
				masterUser = "postgres"
			}
			masterDSN := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password='%s' sslmode=require",
				host, port, dbname, masterUser, escapeDSNValue(masterPw))
			masterDB, err := sql.Open("postgres", masterDSN)
			if err != nil {
				log.Printf("  FAIL (open): %s", err)
				tests["master_connect"] = fmt.Sprintf("FAIL (open): %s", err)
			} else {
				defer masterDB.Close()
				if err := masterDB.PingContext(ctx); err != nil {
					log.Printf("  FAIL (ping): %s", err)
					tests["master_connect"] = fmt.Sprintf("FAIL (ping): %s", err)
				} else {
					tests["master_connect"] = "PASS"
					log.Println("  Master connect: PASS")

					// Engine version from SQL
					var pgVersion string
					if err := masterDB.QueryRowContext(ctx, "SELECT version()").Scan(&pgVersion); err != nil {
						log.Printf("  version() FAIL: %s", err)
					} else {
						tests["pg_version"] = pgVersion
						log.Printf("  PostgreSQL version: %s", pgVersion)
					}

					// Check rds_iam role membership
					var hasRdsIam bool
					err = masterDB.QueryRowContext(ctx,
						`SELECT EXISTS(
							SELECT 1 FROM pg_auth_members
							WHERE roleid = (SELECT oid FROM pg_roles WHERE rolname = 'rds_iam')
							AND member = (SELECT oid FROM pg_roles WHERE rolname = $1)
						)`, username).Scan(&hasRdsIam)
					if err != nil {
						log.Printf("  rds_iam check FAIL: %s", err)
						tests["rds_iam_granted"] = fmt.Sprintf("FAIL: %s", err)
					} else {
						tests["rds_iam_granted"] = fmt.Sprintf("%v", hasRdsIam)
						log.Printf("  rds_iam granted to %s: %v", username, hasRdsIam)
					}

					// Check user login capability + password
					var rolcanlogin bool
					var rolpassword interface{}
					err = masterDB.QueryRowContext(ctx,
						"SELECT rolcanlogin, rolpassword IS NOT NULL FROM pg_authid WHERE rolname = $1", username).Scan(&rolcanlogin, &rolpassword)
					if err != nil {
						log.Printf("  user check FAIL: %s", err)
						tests["user_details"] = fmt.Sprintf("FAIL: %s", err)
					} else {
						tests["user_details"] = fmt.Sprintf("canlogin=%v has_password=%v", rolcanlogin, rolpassword)
						log.Printf("  User: canlogin=%v has_password=%v", rolcanlogin, rolpassword)
					}

					// List all roles for the user
					rows, err := masterDB.QueryContext(ctx,
						`SELECT r.rolname FROM pg_auth_members m
						 JOIN pg_roles r ON r.oid = m.roleid
						 WHERE m.member = (SELECT oid FROM pg_roles WHERE rolname = $1)`, username)
					if err != nil {
						log.Printf("  roles FAIL: %s", err)
						tests["user_roles"] = fmt.Sprintf("FAIL: %s", err)
					} else {
						defer rows.Close()
						var roles []string
						for rows.Next() {
							var r string
							if err := rows.Scan(&r); err == nil {
								roles = append(roles, r)
							}
						}
						tests["user_roles"] = fmt.Sprintf("%v", roles)
						log.Printf("  Roles: %v", roles)
					}

					// Check pg_hba.conf rules (Aurora exposes via pg_hba_file_rules in PG15+)
					hbaRows, err := masterDB.QueryContext(ctx,
						`SELECT line_number, type, database, user_name, auth_method
						 FROM pg_hba_file_rules ORDER BY line_number`)
					if err != nil {
						log.Printf("  pg_hba_file_rules FAIL: %s", err)
						tests["pg_hba"] = fmt.Sprintf("FAIL: %s", err)
					} else {
						defer hbaRows.Close()
						var hbaEntries []string
						for hbaRows.Next() {
							var lineNum int
							var connType, databases, users, authMethod string
							if err := hbaRows.Scan(&lineNum, &connType, &databases, &users, &authMethod); err == nil {
								entry := fmt.Sprintf("L%d: %s db=%s user=%s method=%s", lineNum, connType, databases, users, authMethod)
								hbaEntries = append(hbaEntries, entry)
							}
						}
						tests["pg_hba"] = strings.Join(hbaEntries, " | ")
						log.Printf("  pg_hba_file_rules: %s", tests["pg_hba"])
					}
				}
			}
		}
	} else {
		tests["master_connect"] = "SKIPPED (no MASTER_SECRET_ARN)"
	}

	// --- Step 3: Generate IAM auth token ---
	log.Println("Step 3: Generate IAM auth token...")
	endpoint := fmt.Sprintf("%s:%s", host, port)
	token, err := rdsutils.BuildAuthToken(endpoint, region, username, sess.Config.Credentials)
	if err != nil {
		return Response{Status: "FAIL", Auth: "iam", CallerARN: callerARN,
			Message: fmt.Sprintf("Token generation failed: %s", err), Tests: tests}, nil
	}
	tokenLen := len(token)
	tests["iam_token_length"] = fmt.Sprintf("%d", tokenLen)

	// Log the FULL token (not just prefix) — needed to debug signature issues
	tests["iam_token_full"] = token
	log.Printf("  Token length: %d", tokenLen)
	log.Printf("  Token (full): %s", token)

	// Validate token structure
	tests["token_has_action"] = fmt.Sprintf("%v", strings.Contains(token, "Action=connect"))
	tests["token_has_dbuser"] = fmt.Sprintf("%v", strings.Contains(token, "DBUser="+username))
	tests["token_has_credential"] = fmt.Sprintf("%v", strings.Contains(token, "X-Amz-Credential"))
	tests["token_has_signature"] = fmt.Sprintf("%v", strings.Contains(token, "X-Amz-Signature"))
	tests["token_has_security_token"] = fmt.Sprintf("%v", strings.Contains(token, "X-Amz-Security-Token"))

	// Extract and log the expected rds-db:connect resource ARN
	if clusterResourceID != "" {
		expectedARN := fmt.Sprintf("arn:aws:rds-db:%s:%s:dbuser:%s/%s", region, accountID, clusterResourceID, username)
		tests["expected_rds_db_arn"] = expectedARN
		log.Printf("  Expected rds-db:connect resource ARN: %s", expectedARN)
	}

	// --- Step 4a: Try with lib/pq + sslmode=require (original) ---
	log.Println("Step 4a: lib/pq + sslmode=require...")
	dsn4a := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password=%s sslmode=require",
		host, port, dbname, username, token)
	tests["4a_libpq_require"] = tryConnect(ctx, "postgres", dsn4a)
	log.Printf("  Result: %s", tests["4a_libpq_require"])

	// --- Step 4b: Try with lib/pq + sslmode=verify-full + RDS CA bundle ---
	log.Println("Step 4b: lib/pq + sslmode=verify-full + RDS CA bundle...")
	certFile := "/tmp/rds-ca-bundle.pem"
	if err := os.WriteFile(certFile, []byte(rdsCACert), 0644); err != nil {
		log.Printf("  FAIL writing cert: %s", err)
		tests["4b_libpq_verifyfull"] = fmt.Sprintf("FAIL (cert write): %s", err)
	} else {
		dsn4b := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password=%s sslmode=verify-full sslrootcert=%s",
			host, port, dbname, username, token, certFile)
		tests["4b_libpq_verifyfull"] = tryConnect(ctx, "postgres", dsn4b)
		log.Printf("  Result: %s", tests["4b_libpq_verifyfull"])
	}

	// --- Step 4c: Try with lib/pq + sslmode=verify-ca + RDS CA bundle ---
	log.Println("Step 4c: lib/pq + sslmode=verify-ca + RDS CA bundle...")
	dsn4c := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password=%s sslmode=verify-ca sslrootcert=%s",
		host, port, dbname, username, token, certFile)
	tests["4c_libpq_verifyca"] = tryConnect(ctx, "postgres", dsn4c)
	log.Printf("  Result: %s", tests["4c_libpq_verifyca"])

	// --- Step 4d: Try with pgx driver (most modern Go PG driver) + verify-full ---
	log.Println("Step 4d: pgx + verify-full + RDS CA bundle...")
	tests["4d_pgx_verifyfull"] = tryPgxConnect(ctx, host, port, dbname, username, token)
	log.Printf("  Result: %s", tests["4d_pgx_verifyfull"])

	// --- Determine overall status ---
	status := "FAIL"
	message := ""
	for k, v := range tests {
		if strings.HasPrefix(k, "4") && v == "PASS" {
			status = "PASS"
			message = fmt.Sprintf("%s succeeded", k)
			break
		}
	}
	if status == "FAIL" {
		parts := []string{}
		for k, v := range tests {
			if strings.HasPrefix(k, "4") {
				parts = append(parts, k+":"+v)
			}
		}
		message = strings.Join(parts, " | ")
	}

	log.Printf("=== All diagnostics complete (status=%s) ===", status)

	return Response{
		Status:      status,
		Auth:        "iam",
		User:        username,
		Schema:      schema,
		CallerARN:   callerARN,
		AccountID:   accountID,
		TokenLength: tokenLen,
		Tests:       tests,
		Message:     message,
	}, nil
}

func tryConnect(ctx context.Context, driverName, dsn string) string {
	db, err := sql.Open(driverName, dsn)
	if err != nil {
		return fmt.Sprintf("FAIL (open): %s", err)
	}
	defer db.Close()
	if err := db.PingContext(ctx); err != nil {
		return fmt.Sprintf("FAIL (ping): %s", err)
	}
	return "PASS"
}

func tryPgxConnect(ctx context.Context, host, port, dbname, username, token string) string {
	// Build TLS config with RDS CA bundle (equivalent to Node.js rejectUnauthorized:true + ca:bundle)
	certPool := x509.NewCertPool()
	if !certPool.AppendCertsFromPEM([]byte(rdsCACert)) {
		return "FAIL: could not parse RDS CA cert"
	}
	tlsConfig := &tls.Config{
		RootCAs:    certPool,
		ServerName: host,
	}

	connStr := fmt.Sprintf("host=%s port=%s dbname=%s user=%s password=%s sslmode=verify-full",
		host, port, dbname, username, token)
	connConfig, err := pgx.ParseConfig(connStr)
	if err != nil {
		return fmt.Sprintf("FAIL (parse): %s", err)
	}
	connConfig.TLSConfig = tlsConfig

	conn, err := pgx.ConnectConfig(ctx, connConfig)
	if err != nil {
		return fmt.Sprintf("FAIL (connect): %s", err)
	}
	defer conn.Close(ctx)

	if err := conn.Ping(ctx); err != nil {
		return fmt.Sprintf("FAIL (ping): %s", err)
	}
	return "PASS"
}

func escapeDSNValue(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `'`, `\'`)
	return s
}

func getSecretPassword(sess *session.Session, secretID string) (string, error) {
	client := secretsmanager.New(sess)
	result, err := client.GetSecretValue(&secretsmanager.GetSecretValueInput{
		SecretId: aws.String(secretID),
	})
	if err != nil {
		return "", err
	}
	if result.SecretString == nil {
		return "", fmt.Errorf("secret is binary")
	}
	var m map[string]string
	if err := json.Unmarshal([]byte(*result.SecretString), &m); err != nil {
		return "", err
	}
	pw, ok := m["password"]
	if !ok {
		return "", fmt.Errorf("no password field in secret")
	}
	return pw, nil
}

func main() {
	lambda.Start(handler)
}
