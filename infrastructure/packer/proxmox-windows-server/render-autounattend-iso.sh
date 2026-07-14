#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <packer-var-file> [<packer-var-file> ...]" >&2
  exit 1
fi

work_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
generated_dir="${work_dir}/generated"
iso_root="${generated_dir}/iso-root"
answer_file="${iso_root}/Autounattend.xml"
sysprep_answer_file="${generated_dir}/SysprepUnattend.xml"
iso_file="${generated_dir}/Autounattend.iso"
template_file="${work_dir}/answer_files/Autounattend.xml.pkrtpl"
sysprep_template_file="${work_dir}/answer_files/SysprepUnattend.xml.pkrtpl"

mkdir -p "${iso_root}"

python3 - "$template_file" "$answer_file" "$sysprep_template_file" "$sysprep_answer_file" "$@" <<'PY'
import re
import sys
import xml.sax.saxutils
from pathlib import Path

template_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
sysprep_template_path = Path(sys.argv[3])
sysprep_output_path = Path(sys.argv[4])
var_files = [Path(p) for p in sys.argv[5:]]

values = {
    "windows_computer_name": "PACKER-WIN",
    "windows_image_index": "",
    "windows_input_locale": "en-US",
    "windows_product_key": "",
    "windows_timezone": "W. Europe Standard Time",
}
assignment = re.compile(r'^\s*([A-Za-z0-9_]+)\s*=\s*"(.*)"\s*$')

for var_file in var_files:
    if not var_file.exists():
        continue
    for line in var_file.read_text(encoding="utf-8").splitlines():
        match = assignment.match(line)
        if match:
            values[match.group(1)] = bytes(match.group(2), "utf-8").decode("unicode_escape")

required = [
    "windows_admin_password",
    "windows_computer_name",
    "windows_input_locale",
    "windows_timezone",
]
missing = [key for key in required if not values.get(key)]
if missing:
    raise SystemExit(f"Missing required Packer vars for Autounattend.xml: {', '.join(missing)}")

if values.get("windows_image_index"):
    image_selector_key = "/IMAGE/INDEX"
    image_selector_value = values["windows_image_index"]
elif values.get("windows_image_name"):
    image_selector_key = "/IMAGE/NAME"
    image_selector_value = values["windows_image_name"]
else:
    raise SystemExit("Set windows_image_name or windows_image_index for Autounattend.xml")

mapping = {
    "administrator_password": values["windows_admin_password"],
    "computer_name": values["windows_computer_name"],
    "image_selector_key": image_selector_key,
    "image_selector_value": image_selector_value,
    "input_locale": values["windows_input_locale"],
    "product_key": values.get("windows_product_key", ""),
    "timezone": values["windows_timezone"],
}

def render_template(source_path):
    content = source_path.read_text(encoding="utf-8")

    conditional = re.compile(
        r'%\{\s*if\s+product_key\s*!=\s*""\s*~\}\n(.*?)%\{\s*endif\s*~\}\n',
        re.DOTALL,
    )
    if mapping["product_key"]:
        content = conditional.sub(lambda m: m.group(1), content)
    else:
        content = conditional.sub("", content)

    for key, value in mapping.items():
        content = content.replace("${" + key + "}", xml.sax.saxutils.escape(value))

    return content

output_path.write_text(render_template(template_path), encoding="utf-8")
sysprep_output_path.write_text(render_template(sysprep_template_path), encoding="utf-8")
PY

rm -f "${iso_file}"

if command -v hdiutil >/dev/null 2>&1; then
  hdiutil makehybrid -quiet -iso -joliet -default-volume-name AUTOUNATTEND \
    -o "${iso_file}" "${iso_root}"
elif command -v xorriso >/dev/null 2>&1; then
  xorriso -as mkisofs -quiet -J -r -V AUTOUNATTEND -o "${iso_file}" "${iso_root}"
elif command -v mkisofs >/dev/null 2>&1; then
  mkisofs -quiet -J -r -V AUTOUNATTEND -o "${iso_file}" "${iso_root}"
else
  echo "Need hdiutil, xorriso, or mkisofs to create ${iso_file}" >&2
  exit 1
fi

echo "Generated ${iso_file}"
echo "Generated ${sysprep_answer_file}"
