FROM mcr.microsoft.com/devcontainers/python:3.13-bookworm

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    iputils-ping traceroute mtr-tiny dnsutils netcat-openbsd nmap \
    iperf3 tcpdump openssl snmp \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.lock /tmp/requirements.lock
RUN pip install --no-cache-dir -r /tmp/requirements.lock && rm /tmp/requirements.lock

USER vscode
