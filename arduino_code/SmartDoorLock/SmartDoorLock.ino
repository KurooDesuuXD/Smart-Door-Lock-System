#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"
#include "addons/RTDBHelper.h"
#include "secrets.h"  // ✅ Imported securely

// RFID
#define SS_PIN 21
#define RST_PIN 22
MFRC522 rfid(SS_PIN, RST_PIN);

// Relay
#define RELAY_PIN 4

// WiFi credentials
#define WIFI_SSID "YOUR SSID PUT IT HERE"
#define WIFI_PASSWORD "YOUR WIFI PASSWORD PUT IT HERE"

// Firebase credentials
#define API_KEY "YOUR_FIREBASE_API_KEY"
#define USER_EMAIL "YOUR_EMAIL"
#define USER_PASSWORD "YOUR_PASSWORD"
#define DATABASE_URL "YOUR_DATABASE_URL"

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

String lastUid = "";
unsigned long lastScanTime = 0;
bool rfidResetRequired = false;

void setup() {
  Serial.begin(115200);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);  // Locked

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to Wi-Fi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi connected");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  while (!Firebase.ready()) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ Firebase ready");

  SPI.begin(18, 19, 23, 21);
  rfid.PCD_Init();
  Serial.println("🔄 RFID Initialized");
}

void loop() {
  handleRFID();

  static unsigned long lastCheck = 0;
  if (millis() - lastCheck > 300) {
    lastCheck = millis();
    handleAppUnlock();
    handleClearLogs();
  }

  delay(50);
}

void handleAppUnlock() {
  if (Firebase.ready() && Firebase.RTDB.getString(&fbdo, "/door/status")) {
    String status = fbdo.to<const char *>();
    if (status == "unlocked") {
      Serial.println("📲 App requested unlock");
      digitalWrite(RELAY_PIN, LOW);
      delay(3000);
      digitalWrite(RELAY_PIN, HIGH);

      Firebase.RTDB.setString(&fbdo, "/door/status", "locked");
      Firebase.RTDB.setString(&fbdo, "/door/method", "app");

      FirebaseJson json;
      json.set("status", "unlocked");
      json.set("method", "app");
      json.set("timestamp", String(millis()));
      Firebase.RTDB.pushJSON(&fbdo, "/logs", &json);

      rfid.PCD_Init();
    }
  }
}

void handleClearLogs() {
  if (Firebase.RTDB.getString(&fbdo, "/settings/clearLogs")) {
    String uid = fbdo.to<const char *>();
    String rolePath = "/users/" + uid + "/role";

    if (Firebase.RTDB.getString(&fbdo, rolePath)) {
      String role = fbdo.to<const char *>();
      if (role == "admin") {
        Firebase.RTDB.deleteNode(&fbdo, "/logs");
        Serial.println("🧼 Logs cleared by admin: " + uid);

        Firebase.RTDB.deleteNode(&fbdo, "/settings/clearLogs");
      } else {
        Serial.println("⛔ Not authorized to clear logs");
      }
    } else {
      Serial.println("❌ Failed to verify role");
    }
  }
}

void handleRFID() {
  if (rfidResetRequired) {
    rfid.PCD_Init();
    rfidResetRequired = false;
  }

  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toLowerCase();
  Serial.println("🔍 Scanned UID: " + uid);

  if (uid == lastUid && millis() - lastScanTime < 5000) {
    Serial.println("⏳ Same UID scanned too soon. Ignoring...");
    return;
  }

  lastUid = uid;
  lastScanTime = millis();

  String rolePath = "/users/" + uid + "/role";
  if (Firebase.RTDB.getString(&fbdo, rolePath)) {
    String role = fbdo.to<const char *>();
    Serial.println("👤 Role: " + role);

    if (role == "admin" || role == "user") {
      Serial.println("✅ " + role + " authorized. Unlocking...");
      digitalWrite(RELAY_PIN, LOW);
      delay(3000);
      digitalWrite(RELAY_PIN, HIGH);

      Firebase.RTDB.setString(&fbdo, "/door/status", "locked");
      Firebase.RTDB.setString(&fbdo, "/door/method", "rfid");

      FirebaseJson json;
      json.set("status", "unlocked");
      json.set("method", "rfid");
      json.set("by", role);
      json.set("timestamp", String(millis()));
      Firebase.RTDB.pushJSON(&fbdo, "/logs", &json);
    } else {
      Serial.println("⛔ Role not authorized");
    }
  } else {
    Serial.println("❌ Failed to read role from Firebase");
  }

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  delay(1000);
  rfidResetRequired = true;
}
