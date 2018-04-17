---
layout: post
title: 'Docker & Laravel: l''ambiente di sviluppo'
date: 2017-09-19 14:33:38.000000000 +02:00
type: post
published: true
category: docker
image: posts/docker-banner.jpg
toc: true
tags:
- docker
- laravel
- php
- web
---

# Intro

In questo articolo mosterò come ulizzare [Docker](http://docker.io) per creare un ambiente di sviluppo portabile e isolato per [Laravel](http://laravel.com).

# I container, ovvero come ti impacchetto l'applicazione

Prima di passare al _concreto_, trovo sia necessaria fare una piccola premessa su cosa sono i container e come stanno rivoluzionando l'industria.

![Container vs VM]({{ site.baseurl }}/assets/container_vs_vm.jpg)

Per molti versi possiamo pensare ai _container_ come simili ad una **virtual machine** con alcune sostanziali differenze. La differenza più importante (e più sostanziale) è che una **vm** virtualizza un intero sistema operativo all'interno di un _guest _dovendo anche simulare lo strato hardware, mentre un **container **sfrutta una tecnologia presente nel kernel di Linux chiamata "[LXC - Linux containers](https://linuxcontainers.org/)" per poter _isolare_ una parte del sistema operativo dove far quindi girare le nostre applicazioni. [Docker](http://docker.io) nasce nel 2013 come framework al di sopra di LXC come tool per poter *pacchettizzare* le applicazioni all'interno di _scatole_ che poi vengono eseguite dal kernel, togliendo quindi l'overhead di una macchina virtuale.

# Docker & Laravel

Un esempio di ambiente di sviluppo lo potete trovare sul mio [repository di GItHub](https://github.com/marcocot/php-docker).  Per prima cosa procediamo con il creare il nostro progetto in Laravel:

```bash
$ composer create-project --prefer-dist laravel/laravel blog
$ cd blog/
$ php artisan serve
Laravel development server started: <http://127.0.0.1:8000>
```

Se abbiamo fatto tutto correttamente collegandoci alla porta 8000 della macchina locale visualizzeremo la pagina di default:

![Laravel: pagina di default]({{ site.baseurl }}/assets/Screenshot-from-2017-03-10-07-25-24-1024x562.png)

Per maggiori informazioni su come avviare un progetto in Laravel vi rimando alla [documentazione ufficiale](https://laravel.com/docs/5.4/). Il passo successivo è quindi clonare il mio [repository di esempio](https://github.com/marcocot/php-docker) all'interno del nostro progetto:

```bash
[marco@localhost blog]$ git clone git@github.com:marcocot/php-docker.git docker
Cloning into 'docker'...
remote: Counting objects: 17, done.
remote: Compressing objects: 100% (13/13), done.
remote: Total 17 (delta 1), reused 13 (delta 1), pack-reused 0
Receiving objects: 100% (17/17), done.
Resolving deltas: 100% (1/1), done.
Checking connectivity... done.
[marco@localhost blog]$
```

# Dockerfile

In /docker/php/Dockerfile possiamo trovare la definizione del nostro primo container:

```dockerfile
FROM php:7.1-cli
MAINTAINER Marco Cotrufo <marco.cotrufo@devncode.it>

RUN pecl install xdebug && docker-php-ext-enable xdebug \
&& pecl install -o -f redis \
&& rm -rf /tmp/pear \
&& docker-php-ext-enable redis && \
docker-php-ext-install opcache && \
docker-php-ext-enable opcache && \
docker-php-ext-install pdo pdo\_mysql && docker-php-ext-enable pdo pdo\_mysql

ADD ./xdebug.ini /tmp/xdebug.ini
RUN cat /tmp/xdebug.ini >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

VOLUME /code
WORKDIR /code

EXPOSE 8000
CMD ["php", "artisan", "--host=0.0.0.0", "serve"]
```

Sostanzialmente ci preoccupiamo di _estendere_ il [container ufficiale di php](https://hub.docker.com/_/php/) per eseguire alcune operazioni aggiuntive (4-13):

1.  Attivare l'estensione [xdebug](https://xdebug.org/)
2.  Attivare le estensioni redis, opcache, pdo, pdo_mysql
3.  Copiamo la configurazione di _xdebug_ all'interno del container. Questa configurazione ci permetterà di collegarci a _xdebug_ dall'esterno del container, argomento di un prossimo post.

Alla riga 15 creiamo un _mountpoint_ che ci permetterà di condividere la folder del nostro progetto con il container. Alle righe 18-19 invece istruiamo Docker ad esporre la porta 8000 ed eseguiamo **artisan** per effettuare il _serve_ della nostra applicazione.  
Per i dettagli vi rimando [alla documentazione sulla sintassi](https://docs.docker.com/engine/reference/builder/).

# docker-compose, uniamo i pezzi

Abbiamo visto come creare il _container_ per la nostra applicazione, ma nel nostro ambiente di sviluppo mancano ancora un paio di componenti essenziali: MySQL, Redis, Mailcatcher.  
Visto che il nostro intento è quello di creare un ambiente di sviluppo assolutamente isolato e portabile possiamo trasformare anche questi servizi in _container_. In aiuto ci viene [docker-compose](https://docs.docker.com/compose/): un tool che possiamo utilizzare per definire ed avviare più _container_. Nel file /docker/docker-compose.yml possiamo trovare la configurazione di tutti i nostri servizi/container.

```yaml
version: '2'

services:
  php:
    build:
      context: ./php/

    volumes:
      - ../:/code

    ports:
      - "8080:8000"

    links:
      - db
      - redis
      - mailhog

    environment:
      - DB_HOST=db
      - DB_DATABASE=db
      - DB_USERNAME=root
      - DB_PASSWORD=root

  db:
    build:
      context: ./mariadb

    ports:
      - "3306:3306"

  redis:
    image: "redis:alpine"

  mailhog:
    build:
      context: ./mailhog

    ports:
      - "8081:80"
```

Il punto chiave di questa configurazione sono le chiavi sotto **services**:

```yaml
php:
    build:
      context: ./php/

    volumes:
      - ../:/code

    ports:
      - "8080:8000"

    links:
      - db
      - redis
      - mailhog

    environment:
      - DB_HOST=db
      - DB_DATABASE=db
      - DB_USERNAME=root
      - DB_PASSWORD=root
```

Qui stiamo definendo un servizio di nome **php**:

1.  il cui Dockerfile è presente nella folder ./php/
2.  con cui shariamo il contenuto della folder .. nella folder /code del container
3.  che linkiamo ai servizi db, redis e mailhog
4.  a cui bindiamo la porta locale 8080 del host verso la porta 8000 del container
5.  e a cui passiamo alcune variabili d'ambiente

Il **link** dei servizi (15-17) è necessario per permettere al container **php** di poter comunicare con i container degli altri servizi.  
Per maggiori dettagli sulla sintassi di docker-compose vi rimando alla [documentazione ufficiale](https://docs.docker.com/compose/compose-file/).

# Up&Running

Come ultimo step ci basterà eseguire:

```bash
docker-compose up -d
```

**docker-compose** si preoccuperà di buildare e avviare i singoli container, configurare la rete e montare lo share in modo che il nostro progetto sia disponibile nella folder /code del container **php**.

A questo punto potremo visualizzare l'url [localhost:8080](http://localhost:8080) per accedere al nostro progetto all'interno del container.
