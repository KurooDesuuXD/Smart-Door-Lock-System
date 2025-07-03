#ifndef RTDB_HELPER_H
#define RTDB_HELPER_H

// Print result from RTDB
void printResult(FirebaseData &data) {
  if (data.dataType() == "json") {
    Serial.println(data.jsonString());
  } else {
    Serial.print("Path: ");
    Serial.println(data.dataPath());
    Serial.print("Type: ");
    Serial.println(data.dataType());
    Serial.print("Value: ");
    Serial.println(data.stringData());
  }
}

#endif
