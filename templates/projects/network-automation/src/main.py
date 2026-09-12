# Intended usage once nornir/inventory/hosts.yaml is filled in with real
# devices (runtime deps - nornir, nornir-netmiko, napalm, scrapli - live in
# the Dev Container image, not requirements.txt, so this stays import-free
# for CI):
#
#   from nornir import InitNornir
#   nr = InitNornir(config_file="nornir/config.yaml")
#   for host in nr.inventory.hosts.values():
#       host.username = os.environ["NET_DEVICE_USERNAME"]
#       host.password = os.environ["NET_DEVICE_PASSWORD"]

def main() -> None:
    print("__PROJECT_NAME__")

if __name__ == "__main__":
    main()
