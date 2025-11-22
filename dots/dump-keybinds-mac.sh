#!/usr/bin/env bash

defaults export com.apple.symbolichotkeys - > /tmp/symbolichotkeys.plist
plutil -convert json -o /tmp/symbolichotkeys.json /tmp/symbolichotkeys.plist
cat /tmp/symbolichotkeys.json | \
jq -r '
  .AppleSymbolicHotKeys
  | to_entries
  | map(
      "    \"" + .key + "\" = {\n" +
      "      enabled = " + (
        if (.value.enabled == 1 or .value.enabled == true) then
          "true"
        else
          "false"
        end
      ) + ";\n" +
      (
        if (.value.value? and .value.value.parameters? and .value.value.type?) then
          "      value = {\n" +
          "        parameters = [ " + (
            .value.value.parameters
            | map(tostring)
            | join(" ")
          ) + " ];\n" +
          "        type = \"" + .value.value.type + "\";\n" +
          "      };\n"
        else
          ""
        end
      ) +
      "    };\n"
    )
  | "  AppleSymbolicHotKeys = {\n" + ( join("") ) + "  };\n"
'

