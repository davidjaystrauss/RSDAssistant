#!/usr/bin/env ruby

require "base64"
require "json"
require "openssl"

TEAM_ID = ENV.fetch("APPLE_TEAM_ID")
KEY_ID = ENV.fetch("APPLE_KEY_ID")
P8_PATH = File.expand_path(ENV.fetch("APPLE_P8_PATH"))

def b64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

now = Time.now.to_i

header = {
  alg: "ES256",
  kid: KEY_ID,
  typ: "JWT",
}

payload = {
  iss: TEAM_ID,
  iat: now,
  exp: now + 60 * 60 * 24 * 180,
}

signing_input = [b64url(header.to_json), b64url(payload.to_json)].join(".")
private_key = OpenSSL::PKey.read(File.read(P8_PATH))
digest = OpenSSL::Digest::SHA256.new
signature_der = private_key.dsa_sign_asn1(digest.digest(signing_input))
asn1 = OpenSSL::ASN1.decode(signature_der)
r = asn1.value[0].value.to_s(2).rjust(32, "\x00")
s = asn1.value[1].value.to_s(2).rjust(32, "\x00")
signature = b64url(r + s)

puts [signing_input, signature].join(".")
