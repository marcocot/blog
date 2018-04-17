FROM ruby:2 as builder

WORKDIR /app
COPY . /app

RUN bundle && bundle exec jekyll build

FROM nginx:1-alpine as runtime
COPY --from=0 /app/_site /usr/share/nginx/html