FROM steamcmd/steamcmd@sha256:83d7bfc8c7bbddfc3fd85895811830bbc271218e18eb313a9042833bb057be58

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
