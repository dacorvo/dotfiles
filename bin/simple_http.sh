#!/bin/bash
ROOT=${1:-$(pwd)}
cd ${ROOT}
python -m SimpleHTTPServer ${2}
