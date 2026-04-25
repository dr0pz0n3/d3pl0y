FROM alpine
RUN apk add --no-cache openvpn easy-rsa
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
CMD ["/entrypoint.sh"]
