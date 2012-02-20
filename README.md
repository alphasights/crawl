# Crawl

Crawl pages witin a domain, reporting any page that returns a bad response code

Usage:

    >crawl [options] domain

      -s, --start /home,/about         Starting path(s), defaults to /
      -u, --username username          Basic auth username
      -p, --password password          Basic auth password
      -c, --ci                         Output files for CI integration
      -v, --verbose                    Give details when crawling
      -m, --markup                     Validate HTML markup
      -h, --help                       Show this message