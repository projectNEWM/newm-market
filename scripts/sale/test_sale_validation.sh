#!/bin/bash

# Initialize the base command
cmd="cardano-cli"

# Append to the command
cmd+=" --version"

# Execute the command
eval $cmd


# python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx-purchase.draft', False, debug=True);print(json.dumps(exe_units))" > ../data/exe_units.json