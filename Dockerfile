# By default the Debian exim package has the exim user-name 'Debian-exim' coded into the binary.
# Debian-exim is not a user that is permitted by Heroku (see /etc/passwd when in Heroku container).
# Therefore we need to recompile the debian packages from source to include a name that is accepted by Heroku.
# The user-name 'mail' is in Heroku's /etc/passwd list so we will use that.  Wherever the source code includes 
# 'Debian-exim' we will substitute 'mail' by using the sed utility. 
#
# We can find which source files include 'Debian-exim' by extracting the source with 'apt-get source' then 
# searching the extracted files. 
#
# Once we have built the deb packages we can copy them into stage 2 and install them.

FROM ubuntu AS buildstage

# Packages needed for building deb packages from source
RUN apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    fakeroot \
    dpkg-dev \
    cron \
    netbase

# Uncomment deb-src lines in sources.list
RUN sed -i 's/^# deb-src /deb-src /' /etc/apt/sources.list && \
    apt-get update

# Get the sources for exim4
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y --no-install-recommends source exim4
RUN apt-get -y --no-install-recommends build-dep exim4

# Copy custom Makefile which includes these changes:
# EXIM_USER=ref:mail
# EXIM_GROUP=ref:dyno
# CONFIGURE_GROUP=ref:dyno

WORKDIR /exim4-4.93
COPY Makefile /exim4-4.93/Local/Makefile

# Substitute 'Debian-exim' with 'mail' in all relevant files
RUN sed -i 's/Debian-exim/mail/g' /exim4-4.93/debian/exim4-config.postinst \
    /exim4-4.93/debian/exim4-base.postinst \
    /exim4-4.93/debian/exim4-base.exim4.init \
    /exim4-4.93/debian/exim4-base.cron.daily \
    /exim4-4.93/debian/EDITME.exim4-light.diff \
    /exim4-4.93/debian/exim-gencert \
    /exim4-4.93/debian/rules \
    /exim4-4.93/debian/debconf/update-exim4.conf

# My exim config file.  Not sure if this is needed at build stage
COPY ./exim4.conf /etc/exim4/

# Now build the deb packages
RUN dpkg-buildpackage -rfakeroot -uc -b


# Second stage

FROM ubuntu

# Install exim dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
    cron \
    netbase \
    libgnutls-dane0 \
    libidn11 \
    nano

# Copy deb packages from first stage ("buildstage")
COPY --from=buildstage ["/exim4-config_4.93-13ubuntu1.1_all.deb", "/"]
COPY --from=buildstage ["/exim4-base_4.93-13ubuntu1.1_amd64.deb", "/"]
COPY --from=buildstage ["/exim4-daemon-light_4.93-13ubuntu1.1_amd64.deb", "/"]
COPY --from=buildstage ["/exim4_4.93-13ubuntu1.1_all.deb", "/"]

#
# Custom configuration 
# 
# Make it readable for group as well as owner.
# Custom settings include:
#
# daemon_smtp_ports = 587
# tls_on_connect_ports = 587
# exim_user = placeholder
# exim_group = dyno
# gmail_smtp:
#   driver = smtp
#   port = 587
#   hosts_require_auth = *
#   hosts_require_tls = *
# gmail_login:
#   driver = plaintext
#   public_name = LOGIN
#   client_send = : warwick.mcnaughton@gmail.com : <secret password>
#
# In the running container it will be necessary to call exim with the -C option:
# exim -C /etc/exim4/exim4.conf -v warwick.mcnaughton@gmail.com

COPY ./exim4.conf /etc/exim4/
RUN  chmod 660 /etc/exim4/exim4.conf

# Install exim from the deb packages
WORKDIR /
RUN dpkg -i exim4-config_4.93-13ubuntu1.1_all.deb && \
    dpkg -i exim4-base_4.93-13ubuntu1.1_amd64.deb && \
    dpkg -i exim4-daemon-light_4.93-13ubuntu1.1_amd64.deb && \
    dpkg -i exim4_4.93-13ubuntu1.1_all.deb

# Replace exim_user in exim4.conf with the Heroku assigned user 
COPY entry.sh /
RUN chmod +x /entry.sh
ENTRYPOINT [ "/entry.sh" ]

CMD ["bash"]