FROM tianon/exim4:latest

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["tini", "--", "exim", "-bd", "-v"]
