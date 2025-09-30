# -------------------------
# Stage 1 : Builder
# -------------------------
FROM ruby:3.2-slim AS builder

ENV APP_PATH=/app/openproject
WORKDIR $APP_PATH

# Installer toutes les dépendances nécessaires pour compiler les gems et assets
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl gnupg \
    libpq-dev libmagickwand-dev libxml2-dev libxslt1-dev \
    nodejs npm \
    imagemagick poppler-utils tesseract-ocr unrtf catdoc \
    && rm -rf /var/lib/apt/lists/*

# Installer Bundler 2.4
RUN gem install bundler -v "~> 2.4" --no-document
ENV PATH="/usr/local/bundle/bin:$PATH"

# Préparer les permissions pour l’UID OpenShift
RUN mkdir -p $APP_PATH && chgrp -R 0 $APP_PATH && chmod -R g+rwX $APP_PATH

# Copier Gemfile et Gemfile.lock (OpenShift clone déjà le repo)
COPY Gemfile Gemfile.lock ./

# Installer les gems (sans test/development/mysql2)
RUN bundle install --deployment --with="docker opf_plugins" --without="test development mysql2"

# Copier tout le code source
COPY . $APP_PATH

# Compiler les assets JS/CSS
RUN npm install && bash docker/precompile-assets.sh

# -------------------------
# Stage 2 : Runtime
# -------------------------
FROM ruby:3.2-slim

ENV APP_PATH=/app/openproject
WORKDIR $APP_PATH

# Installer dépendances runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 imagemagick poppler-utils tesseract-ocr unrtf catdoc nodejs \
    && rm -rf /var/lib/apt/lists/*

# Préparer dossier pour UID aléatoire OpenShift
RUN mkdir -p $APP_PATH && chgrp -R 0 $APP_PATH && chmod -R g+rwX $APP_PATH

# Copier l’application depuis le builder
COPY --from=builder /app/openproject $APP_PATH

# Exposer le port utilisé par OpenShift
EXPOSE 8080

# Entrypoint et CMD
ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["bash", "-c", "bundle exec rails server -b 0.0.0.0 -p 8080"]
