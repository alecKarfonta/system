FROM python:3.11



RUN rm -f /etc/apt/sources.list.d/*.list

RUN apt-get update && \
    apt-get install -y --allow-unauthenticated --no-install-recommends \
    wget \
    git \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Install some basic utilities.
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
&& rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y build-essential \
    && apt-get install -y mlocate \
    && apt-get install -y nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install -r requirements.txt

#SHELL ["/bin/bash", "--login", "-c"]

CMD ["bash"]