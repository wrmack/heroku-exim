# Heroku-exim

I was able to run exim inside a docker container on Heroku with this dockerfile to send emails using Gmail as a relay.

For security reasons Heroku replaces users and groups with its own user and the group 'dyno'.  This makes running exim difficult because Debian hard-codes the user 'Debian-exim' into the binaries.  It was neceessary to compile exim from source using different user names. The dockerfile is documented.

