#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${HOME}/.venvs/pvs-video-models"
PRESET="${1:-wan2.1-echomimic}"

if [ ! -d "${VENV_DIR}" ]; then
  echo "Creating Python virtual environment at ${VENV_DIR}..."
  python3 -m venv "${VENV_DIR}"
fi

"${VENV_DIR}/bin/python" -m pip install --upgrade pip huggingface_hub
"${VENV_DIR}/bin/python" "${SCRIPT_DIR}/download_offline_models.py" --preset "${PRESET}"
