# Dockerfile
FROM python:3.5

# PostgreSQL dev headers and client (uncomment if you use PostgreSQL)
#RUN apt-install libpq-dev postgresql-client-9.3 postgresql-contrib-9.3

# Add requirements.txt ONLY, then run pip install, so that Docker cache won't
# bust when changes are made to other repo files
ADD requirements.txt /app/
WORKDIR /app
RUN pip install -r requirements.txt

# Add repo contents to image
ADD app/ /app/
ADD . /app

# Install Datadog
RUN apt-get update && apt-get install -y apt-transport-https supervisor && rm -rf /var/lib/apt/lists/*
RUN sh -c "echo 'deb https://apt.datadoghq.com/ stable 6' > /etc/apt/sources.list.d/datadog.list"
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 382E94DE
RUN apt-get update && apt-get install -y datadog-agent
RUN cp /etc/datadog-agent/datadog.yaml.example /etc/datadog-agent/datadog.yaml
RUN set -a  && /bin/sed -i "s/api_key:.*/api_key: $DD_API_KEY/" /etc/datadog-agent/datadog.yaml
# Gunicorn runs on port 5000, so move Datadog somewhere else
RUN /bin/sed -i "s/# expvar_port:.*/expvar_port: 5010/" /etc/datadog-agent/datadog.yaml

# Configure trace agent
RUN set -a  && mkdir /etc/dd-agent/ && echo "[Main]\ndd_url: https://app.datadoghq.com\napi_key: $DD_API_KEY\napm_enabled: true" >> /etc/dd-agent/datadog.conf

# Configure supervisor to run gunicorn, datadog agent, and datadog trace agent
RUN echo "[program:web]\ncommand=gunicorn app:app -b 0.0.0.0:5000 --access-logfile - --chdir=/app" >> /etc/supervisor/conf.d/web.conf
RUN echo '[program:datadog-agent]\ncommand=/opt/datadog-agent/bin/agent/agent start\nautostart=true\nautorestart=true' >> /etc/supervisor/conf.d/datadog-agent.conf
RUN echo '[program:datadog-trace-agent]\ncommand=/opt/datadog-agent/embedded/bin/trace-agent\nautostart=true\nautorestart=true' >> /etc/supervisor/conf.d/datadog-agent.conf



ENV PORT 5000
EXPOSE 5000

CMD ["honcho", "start", "-f", "/app/honcho.cnf"]
