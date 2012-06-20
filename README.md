# Crawl

Crawl pages witin a domain, reporting any page that returns a bad response code

Usage:

    > crawl [options] domain

    -s, --start /home,/about         Starting path(s), defaults to /
    -u, --username username          Basic auth username
    -p, --password password          Basic auth password
    -v, --verbose                    Give details when crawling
    -m, --markup                     Validate markup
    -h, --help                       Show this message

Example:

    > crawl http://alphasights.com --start=/no-such-page --verbose

      Adding /no-such-page
    Fetching /no-such-page ...

    Pages with errors:
    /no-such-page found on the command line - Status code: 404

