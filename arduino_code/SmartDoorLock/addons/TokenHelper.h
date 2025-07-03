#ifndef TOKEN_HELPER_H
#define TOKEN_HELPER_H

#include <Arduino.h>
#include <Firebase_ESP_Client.h>

// Declare these first so they're known to tokenStatusCallback
String getTokenType(TokenInfo info);
String getTokenStatus(TokenInfo info);

// Show the status of token generation
void tokenStatusCallback(TokenInfo info) {
  Serial.printf("Token info: type = %s, status = %s\n",
                getTokenType(info).c_str(),
                getTokenStatus(info).c_str());
}

String getTokenType(TokenInfo info) {
  switch (info.type) {
    case token_type_legacy_token:
      return "Legacy token";
    case token_type_id_token:
      return "ID token";
    default:
      return "Unknown";
  }
}

String getTokenStatus(TokenInfo info) {
  switch (info.status) {
    case token_status_uninitialized:
      return "Uninitialized";
    case token_status_on_signing:
      return "On signing";
    case token_status_on_request:
      return "On request";
    case token_status_on_refresh:
      return "On refresh";
    case token_status_ready:
      return "Ready";
    case token_status_error:
      return "Error";
    default:
      return "Unknown";
  }
}

#endif
