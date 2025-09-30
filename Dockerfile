FROM ruby:3-slim-trixie AS builder

ENV APP_PATH=/app/openproject

WORKDIR $APP_PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl gnupg \
    libpq-dev libmagickwand-dev libxml2-dev libxslt1-dev \
    nodejs npm \
    imagemagick poppler-utils tesseract-ocr unrtf catdoc \
    && rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v "~> 2.3" --no-document

COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --with="docker opf_plugins" --without="test development mysql2"

COPY . $APP_PATH
RUN npm install && bash docker/precompile-assets.sh

# -------------------------
FROM ruby:3-slim-trixie

ENV APP_PATH=/app/openproject

WORKDIR $APP_PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 imagemagick poppler-utils tesseract-ocr unrtf catdoc nodejs \
    && rm -rf /var/lib/apt/lists/*

# OpenShift injectera son propre UID
RUN mkdir -p $APP_PATH && chgrp -R 0 $APP_PATH && chmod -R g+rwX $APP_PATH

COPY --from=builder /app/openproject $APP_PATH

EXPOSE 8080
ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["bash", "-c", "bundle exec rails server -b 0.0.0.0 -p 8080"]
