#!/bin/bash


[ ! -f ../.VERSION.mk ] && make -C .. .VERSION.mk

. ../.VERSION.mk

if ! git show-ref --tags | grep -q "$(git rev-parse HEAD)"; then
	# HEAD is not tagged, add the date, time and commit hash to the revision
	BUILD_TIME="$(date +%Y%m%d%H%M)"
	DEB_REVISION="${BUILD_TIME}~${REVISION}"
	RPM_REVISION=".${BUILD_TIME}.${REVISION}"
fi


URL="http://logstash.net"
DESCRIPTION="An extensible logging pipeline"

if [ "$#" -ne 2 ] ; then
  echo "Usage: $0 <os> <release>"
  echo 
  echo "Example: $0 ubuntu 12.10"
  exit 1
fi

os=$1
release=$2

echo "Building package for $os $release"

destdir=build/$(echo "$os" | tr ' ' '_')
prefix=/opt/logstash

if [ "$destdir/$prefix" != "/" -a -d "$destdir/$prefix" ] ; then
  rm -rf "$destdir/$prefix"
fi

mkdir -p $destdir/$prefix


# install logstash.jar
jar="$(dirname $0)/../build/logstash-$VERSION-flatjar.jar"
if [ ! -f "$jar" ] ; then
  echo "Unable to find $jar"
  exit 1
fi

cp $jar $destdir/$prefix/logstash.jar

case $os@$release in
  centos@*)
    mkdir -p $destdir/etc/logrotate.d
    mkdir -p $destdir/etc/sysconfig
    mkdir -p $destdir/etc/init.d
    mkdir -p $destdir/etc/logstash/conf.d
    mkdir -p $destdir/opt/logstash/tmp
    mkdir -p $destdir/var/lib/logstash
    mkdir -p $destdir/var/run/logstash
    mkdir -p $destdir/var/log/logstash
    cp $os/sysconfig $destdir/etc/sysconfig/logstash
    install -m644 logrotate.conf $destdir/etc/logrotate.d/logstash
    install -m755 logstash.sysv.redhat $destdir/etc/init.d/logstash
    ;;
  ubuntu@*)
    mkdir -p $destdir/etc/logstash/conf.d
    mkdir -p $destdir/etc/logrotate.d
    mkdir -p $destdir/etc/init
    mkdir -p $destdir/var/lib/logstash
    mkdir -p $destdir/var/log/logstash
    mkdir -p $destdir/etc/default
    touch $destdir/etc/default/logstash
    install -m644 logrotate.conf $destdir/etc/logrotate.d/logstash
    install -m644 logstash.default $destdir/etc/default/logstash
    install -m644 logstash-web.default $destdir/etc/default/logstash-web
    install -m755 logstash.upstart.ubuntu $destdir/etc/init/logstash.conf
    install -m755 logstash-web.upstart.ubuntu $destdir/etc/init/logstash-web.conf
    ;;
  debian@*)
    mkdir -p $destdir/etc/logstash/conf.d
    mkdir -p $destdir/etc/logrotate.d
    mkdir -p $destdir/etc/init.d
    mkdir -p $destdir/var/lib/logstash
    mkdir -p $destdir/var/log/logstash
    mkdir -p $destdir/etc/default
    touch $destdir/etc/default/logstash
    install -m644 logrotate.conf $destdir/etc/logrotate.d/logstash
    install -m644 logstash.default $destdir/etc/default/logstash
    install -m644 logstash-web.default $destdir/etc/default/logstash-web
    install -m755 logstash.sysv.debian $destdir/etc/init.d/logstash
    install -m755 logstash-web.sysv.debian $destdir/etc/init.d/logstash-web
    ;;
  *) 
    echo "Unknown OS: $os $release"
    exit 1
    ;;
esac

description="logstash is a system for managing and processing events and logs"
case $os in
  centos|fedora|redhat) 
    fpm -s dir -t rpm -n logstash -v "$RELEASE" \
      -a noarch --iteration "1_${os}${RPM_REVISION}" \
      --url "$URL" \
      --description "$DESCRIPTION" \
      -d "jre >= 1.6.0" \
      --vendor "Elasticsearch" \
      --license "Apache 2.0" \
      --before-install centos/before-install.sh \
      --before-remove centos/before-remove.sh \
      --after-install centos/after-install.sh \
      --config-files etc/sysconfig/logstash \
      --config-files etc/logrotate.d/logstash \
      -f -C $destdir .
    ;;
  ubuntu|debian)
    if ! echo $RELEASE | grep -q '\.(dev\|rc.*)'; then
      # This is a dev or RC version... So change the upstream version
      # example: 1.2.2.dev => 1.2.2~dev
      # This ensures a clean upgrade path.
      RELEASE="$(echo $RELEASE | sed 's/\.\(dev\|rc.*\)/~\1/')"
    fi

    fpm -s dir -t deb -n logstash -v "$RELEASE" \
      -a all --iteration "1-${os}${DEB_REVISION}" \
      --url "$URL" \
      --description "$DESCRIPTION" \
      --vendor "Elasticsearch" \
      --license "Apache 2.0" \
      -d "java7-runtime-headless | java6-runtime-headless" \
      --deb-user root --deb-group root \
      --before-install $os/before-install.sh \
      --before-remove $os/before-remove.sh \
      --after-install $os/after-install.sh \
      --config-files /etc/default/logstash \
      --config-files /etc/default/logstash-web \
      --config-files /etc/logrotate.d/logstash \
      -f -C $destdir .
    ;;
esac
