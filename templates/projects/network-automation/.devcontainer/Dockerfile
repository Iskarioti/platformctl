FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping traceroute mtr-tiny dnsutils netcat-openbsd nmap \
    iperf3 tcpdump openssl snmp \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    netmiko nornir nornir-netmiko napalm scrapli pydantic typer rich

USER vscode
