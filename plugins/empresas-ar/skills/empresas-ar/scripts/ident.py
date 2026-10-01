#!/usr/bin/env python3
"""Validate and normalise company identifiers: CUIT/CUIL, email, domain.

    ident.py cuit 30-71234567-8
    ident.py email Juan@Empresa.com.ar
    ident.py domain https://www.empresa.com.ar/contacto
    printf '30712345678\njuan@gmail.com\n' | ident.py auto      # one per line

Prints one JSON object per input. Standard library only, no network.
"""
import json
import re
import sys

WEIGHTS = (5, 4, 3, 2, 7, 6, 5, 4, 3, 2)
PERSON = {"20", "23", "24", "27"}
COMPANY = {"30", "33", "34"}

# Mailbox providers: an address here says nothing about the company.
FREE_MAIL = {
    "gmail.com", "googlemail.com", "hotmail.com", "hotmail.com.ar", "outlook.com",
    "outlook.com.ar", "live.com", "live.com.ar", "msn.com", "yahoo.com",
    "yahoo.com.ar", "icloud.com", "me.com", "aol.com", "gmx.com", "proton.me",
    "protonmail.com", "fibertel.com.ar", "speedy.com.ar", "arnet.com.ar",
    "telecentro.com.ar", "ciudad.com.ar", "uol.com.ar",
}
# Second-level suffixes under .ar: the registrable domain keeps three labels.
AR_SLD = {"com", "org", "net", "gob", "gov", "edu", "mil", "tur", "int", "coop", "mutual"}


def cuit(raw):
    digits = re.sub(r"\D", "", raw)
    out = {"input": raw, "type": "cuit", "digits": digits}
    if len(digits) != 11:
        return {**out, "valid": False, "reason": "needs 11 digits"}
    prefix = digits[:2]
    total = sum(int(d) * w for d, w in zip(digits[:10], WEIGHTS))
    check = 11 - total % 11
    check = 0 if check == 11 else check
    last = int(digits[10])
    # check == 10 has no digit: AFIP reassigns those to prefix 23 with 9 (male) or 4 (female)
    valid = last == check or (check == 10 and prefix == "23" and last in (9, 4))
    kind = "company" if prefix in COMPANY else "person" if prefix in PERSON else "unknown"
    out.update(
        valid=valid,
        formatted=f"{digits[:2]}-{digits[2:10]}-{digits[10]}",
        kind=kind,
    )
    if kind == "unknown":
        out["valid"] = False
        out["reason"] = f"prefix {prefix} is not a known AFIP prefix"
    elif not valid:
        out["reason"] = f"check digit should be {check if check != 10 else '9 or 4'}"
    if kind == "person" and valid:
        out["dni"] = digits[2:10].lstrip("0")
    return out


def domain(raw):
    host = raw.strip().lower()
    host = re.sub(r"^[a-z][a-z0-9+.-]*://", "", host)
    host = host.split("/")[0].split("?")[0].split("@")[-1].split(":")[0].strip(".")
    if not re.fullmatch(r"[a-z0-9-]+(\.[a-z0-9-]+)+", host):
        return {"input": raw, "type": "domain", "valid": False, "reason": "not a hostname"}
    labels = host.split(".")
    keep = 3 if len(labels) >= 3 and labels[-1] == "ar" and labels[-2] in AR_SLD else 2
    reg = ".".join(labels[-keep:])
    return {
        "input": raw, "type": "domain", "valid": True, "host": host,
        "domain": reg, "free_mail": reg in FREE_MAIL,
    }


def email(raw):
    addr = raw.strip().lower().removeprefix("mailto:")
    m = re.fullmatch(r"([^@\s<>]+)@([^@\s<>]+)", addr)
    if not m:
        return {"input": raw, "type": "email", "valid": False, "reason": "not an address"}
    d = domain(m.group(2))
    if not d["valid"]:
        return {"input": raw, "type": "email", "valid": False, "reason": "bad domain"}
    local = m.group(1).split("+")[0]
    return {
        "input": raw, "type": "email", "valid": True, "address": f"{m.group(1)}@{d['host']}",
        "local": local, "domain": d["domain"], "free_mail": d["free_mail"],
        # a free-mail address identifies a person, never a company
        "company_signal": not d["free_mail"],
    }


def auto(raw):
    s = raw.strip()
    if "@" in s:
        return email(s)
    if len(re.sub(r"\D", "", s)) == 11 and re.fullmatch(r"[\d\s.-]+", s):
        return cuit(s)
    return domain(s)


KINDS = {"cuit": cuit, "email": email, "domain": domain, "auto": auto}


def main(argv):
    if len(argv) < 2 or argv[1] not in KINDS:
        sys.exit(__doc__)
    fn = KINDS[argv[1]]
    items = argv[2:] or [l for l in sys.stdin.read().splitlines() if l.strip()]
    for item in items:
        print(json.dumps(fn(item), ensure_ascii=False))


if __name__ == "__main__":
    main(sys.argv)
