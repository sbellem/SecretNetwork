#!/bin/bash

set -e

docker compose exec localsecret-2 ./scripts/set_init_states_toy_swap.sh
docker compose exec localsecret-2 ./scripts/setup_snip20.sh
#docker-compose exec localsecret-2 ./debug_scripts/set_init_states_simple.sh

docker compose stop localsecret-1
