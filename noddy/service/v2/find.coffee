
import Future from 'fibers/future'
import unidecode from 'unidecode'

#oab_find.remove '*'
#oab_catalogue.remove '*'

API.service.oab.ftitle = (title) ->
  # a useful way to show a title (or other string) as one long string with no weird characters, and no words shorter than 2 chars, for easier fuzzy matching
  ft = ''
  for tp in unidecode(title.toLowerCase()).replace(/[^a-z0-9 ]/g,'').replace(/ +/g,' ').split(' ')
    ft += tp if tp.length > 2
  return ft

_finder = (metadata) ->
  finder = ''
  for tid in ['doi','pmid','pmcid','url','title']
    if typeof metadata[tid] is 'string' or typeof metadata[tid] is 'number' or _.isArray metadata[tid]
      mt = if _.isArray metadata[tid] then metadata[tid][0] else metadata[tid]
      if typeof mt is 'number' or (typeof mt is 'string' and mt.length > 5) # people pass n/a and such into title, so ignore anything too small to be a title or a valid id
        finder += ' OR ' if finder isnt ''
        if tid is 'title'
          finder += 'ftitle:' + API.service.oab.ftitle(mt) + '~ OR '
        finder += 'metadata.' + tid + (if tid is 'url' or tid is 'title' then '' else '.exact') + ':"' + mt + '"'
  return finder

oab_catalogue.finder = (metadata) ->
  finder = _finder metadata
  return if finder isnt '' then oab_catalogue.find(finder, true) else undefined

_find =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts[p] ?= this.queryParams[p] for p of this.queryParams
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    opts.url = opts.url[0] if _.isArray opts.url
    if not opts.test and opts.url and API.service.oab.blacklist(opts.url) is true
      API.log 'find request blacklisted for ' + JSON.stringify opts
      return 400
    else
      return API.service.oab.find opts

API.add 'service/oab/find', get:_find, post:_find
API.add 'service/oab/finds', () -> return oab_find.search this
API.add 'service/oab/found', () -> return oab_catalogue.search this, {restrict:[{exists: {field:'url'}}]}
API.add 'service/oab/catalogue', () -> return oab_catalogue.search this
API.add 'service/oab/catalogue/:cid', get: () -> return oab_catalogue.get this.urlParams.cid

API.add 'service/oab/metadata',
  get: () -> return API.service.oab.metadata this.queryParams
  post: () -> return API.service.oab.metadata this.request.body


# exists for legacy reasons, _avail should be altered to make sure the _find returns what _avail used to
_avail =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts[p] ?= this.queryParams[p] for p of this.queryParams
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    opts.url = opts.url[0] if _.isArray opts.url
    if not opts.test and opts.url and API.service.oab.blacklist(opts.url) is true
      API.log 'find request blacklisted for ' + JSON.stringify opts
      return 400
    else
      afnd = {data: {availability: [], requests: [], accepts: [], meta: {article: {}, data: {}}}}
      afnd.data.match = opts.doi ? opts.pmid ? opts.pmc ? opts.pmcid ? opts.title ? opts.url ? opts.id ? opts.citation ? opts.q
      afnd.v2 = API.service.oab.find opts
      try
        afnd.data.ill = afnd.v2.ill
        afnd.data.meta.article = _.clone(afnd.v2.metadata) if afnd.v2.metadata?
        afnd.data.meta.cache = afnd.v2.cached
        afnd.data.meta.refresh = afnd.v2.refresh
        afnd.data.meta.article.url = afnd.data.meta.article.url[0] if _.isArray afnd.data.meta.article.url
        afnd.data.availability.push({type: 'article', url: afnd.v2.url}) if afnd.v2.url
      try
        finder = _finder(afnd.v2.metadata)
        if finder isnt '' and request = oab_request.find '(' + finder + ') AND type:article'
          rq = type: 'article', _id: request._id
          rq.ucreated = if opts.uid and request.user?.id is opts.uid then true else false
          rq.usupport = if opts.uid then API.service.oab.supports(request._id, opts.uid)? else false
          afnd.data.requests.push rq
      return afnd
API.add 'service/oab/availability', get:_avail, post:_avail
API.add 'service/oab/availabilities', () -> return oab_find.search this



API.service.oab.metadata = (options={}, content) -> # pass-through to find that ensures the settings will get metadata rather than fail fast on find
  options.metadata ?= true
  options.find = false
  return API.service.oab.find(options, undefined, content).metadata

API.service.oab.find = (options={}, metadata={}, content) ->
  _get = (metadata, info) ->
    for i of info
      metadata[i] ?= info[i] if info[i]
  _got = (obj=metadata) ->
    for w in options.metadata
      if not obj[w]?
        return false
    return true
  API.log msg: 'OAB finding academic content', level: 'debug'
  started = Date.now()
  res = {url: false}

  if typeof options is 'string'
    metadata = options
    options = {}
  options = {} if typeof options isnt 'object'
  if typeof metadata is 'string'
    options.url = metadata
    metadata = {}
  else if typeof metadata isnt 'object'
    metadata = {}
  else if not metadata? and typeof options.metadata is 'object' and not _.isArray options.metadata
    metadata = options.metadata
    options.metadata = true
  options.metadata = if options.metadata is true then ['title','doi','author','journal','issn','volume','issue','page','published','year'] else if _.isArray(options.metadata) then options.metadata else []
  content ?= options.dom if options.dom?

  if content and _.isEmpty metadata
    _get metadata, API.service.oab.scrape undefined, content

  if metadata.url
    options.url ?= metadata.url
  if metadata.id
    options.id = metadata.id
    delete metadata.id
  options.url = options.url[0] if _.isArray options.url
  res.checked = []

  metadata.doi ?= options.doi.replace('doi:','').replace('doi.org/','').trim() if typeof options.doi is 'string'
  metadata.title ?= options.title.trim() if typeof options.title is 'string'
  metadata.pmid ?= options.pmid if options.pmid
  metadata.pmcid ?= options.pmcid if options.pmcid
  metadata.pmcid ?= options.pmc if options.pmc
  if options.q
    options.url = options.q
    delete options.q
  if options.id
    options.url = options.id
    delete options.id
  if options.url
    if options.url.indexOf('/10.') isnt -1
      # we don't use a regex to try to pattern match a DOI because people often make mistakes typing them, so instead try to find one
      # in ways that may still match even with different expressions (as long as the DOI portion itself is still correct after extraction we can match it)
      dd = '10.' + options.url.split('/10.')[1].split('&')[0].split('#')[0]
      if dd.indexOf('/') isnt -1 and dd.split('/')[0].length > 6 and dd.length > 8
        dps = dd.split('/')
        dd = dps[0] + '/' + dps[1] if dps.length > 2
        metadata.doi = dd
    if options.url.replace('doi:','').replace('doi.org/','').trim().indexOf('10.') is 0
      metadata.doi ?= options.url.replace('doi:','').replace('doi.org/','').trim()
      options.url = 'https://doi.org/' + metadata.doi
    else if options.url.toLowerCase().indexOf('pmc') is 0
      metadata.pmcid ?= options.url.toLowerCase().replace('pmcid','').replace('pmc','')
      options.url = 'http://europepmc.org/articles/PMC' + metadata.pmcid
    else if options.url.replace(/pmid/i,'').replace(':','').length < 10 and options.url.indexOf('.') is -1 and not isNaN(parseInt(options.url.replace(/pmid/i,'').replace(':','').trim()))
      metadata.pmid ?= options.url.replace(/pmid/i,'').replace(':','').trim()
      options.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + metadata.pmid
    else if not metadata.title? and options.url.indexOf('http') isnt 0
      metadata.title = options.url
    delete options.url if options.url.indexOf('http') isnt 0 or options.url.indexOf('.') is -1
  metadata.doi = metadata.doi.replace('doi.org/','').trim() if metadata.doi? and metadata.doi.indexOf('doi.org/') is 0
  metadata.doi = metadata.doi.replace('doi:','').trim() if metadata.doi? and metadata.doi.indexOf('doi:') is 0
  delete metadata.doi if metadata.doi and metadata.doi.indexOf('10.') isnt 0
  if metadata.title and (metadata.title.indexOf('{') isnt -1 or (metadata.title.replace('...','').match(/\./gi) || []).length > 3 or (metadata.title.match(/\(/gi) || []).length > 2)
    options.citation = metadata.title # titles that look like citations
    delete metadata.title
  if options.citation? and not metadata.title and not metadata.doi
    options.citation = options.citation.replace(/citation\:/gi,'').trim()
    if options.citation.indexOf('doi:') isnt -1
      metadata.doi = options.citation.split('doi:')[1].split(',')[0].split(' ')[0].trim()
    else if options.citation.indexOf('{') is 0 or options.citation.indexOf('[') is 0 # look for dumped citation styles
      try _get metadata, JSON.parse options.citation
    else
      try
        options.citation = options.citation.split('title')[1].trim() if options.citation.indexOf('title') isnt -1
        options.citation = options.citation.trim("'").trim('"')
        if options.citation.indexOf('|') isnt -1
          metadata.title = options.citation.split('|')[0].trim()
        else if options.citation.indexOf('}') isnt -1
          metadata.title = options.citation.split('}')[0].trim()
        else if options.citation.indexOf('"') isnt -1 or options.citation.indexOf("'") isnt -1
          metadata.title = options.citation.split('"')[0].split("'")[0].trim()
  metadata.title = metadata.title.replace(/(<([^>]+)>)/g,'').replace(/\+/g,' ').trim() if typeof metadata.title is 'string'

  options.permissions ?= false # don't get permissions by default now that the permissions check could take longer

  res.plugin = options.plugin if options.plugin?
  res.from = options.from if options.from?
  res.all = options.all ? false
  res.parallel = options.parallel ? true
  res.find = options.find ? true
  # other possible sources are ['base','dissemin','share','core','openaire','bing']
  res.sources = options.sources ? ['oabutton','crossref','epmc','reverse','scrape','oadoi','figshare','doaj']
  res.sources.push('bing') if options.plugin in ['widget','oasheet'] or options.from in ['illiad','clio'] or (options.url? and options.url.indexOf('alma.exlibrisgroup.com') isnt -1)
  try res.refresh = if options.refresh is false then 30 else if options.refresh is true then 0 else parseInt options.refresh
  res.refresh = 30 if typeof res.refresh isnt 'number' or isNaN res.refresh
  res.embedded ?= options.embedded if options.embedded?
  res.pilot = options.pilot if options.pilot? # instantill and shareyourpaper can state if they are live or pilot, and if wrong item supplied
  res.live = options.live if options.live?
  res.wrong = options.wrong if options.wrong?
  res.found = {}

  # special cases for instantill/shareyourpaper/other demos and exlibris - dev and live demo accounts that always return a fixed answer
  if (options.plugin is 'instantill' or options.plugin is 'shareyourpaper') and (metadata.doi is '10.1234/567890' or (metadata.doi? and metadata.doi.indexOf('10.1234/oab-syp-') is 0) or metadata.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL') and options.from in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86'] 
    res.metadata = {title: 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL', year: '2019', doi: 'https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y'}
    res.metadata.journal = 'Proceedings of the 16th IFLA ILDS conference: Beyond the paywall - Resource sharing in a disruptive ecosystem'
    res.metadata.author = [{given: 'Mike', family: 'Paxton'}, {given: 'Gary', family: 'Maixner III'}, {given: 'Joseph', family: 'McArthur'}, {given: 'Tina', family: 'Baich'}]
    res.ill = {openurl: ""}
    res.ill.subscription = {findings:{}, uid: options.from, lookups:[], error:[], url: 'https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y', demo: true}
    res.permissions = API.service.oab.permissions(metadata) if options.permissions
    return res
  if not metadata.title and content and typeof options.url is 'string' and (options.url.indexOf('alma.exlibrisgroup.com') isnt -1 or options.url.indexOf('/exlibristest') isnt -1)
    # switch exlibris URLs for titles, which the scraper knows how to extract, because the exlibris url would always be the same
    delete options.url
    res.exlibris = true
    _get metadata, API.service.oab.scrape undefined, content

  API.log msg: 'OAB finding academic content', level: 'debug', metadata: JSON.stringify metadata
  try metadata[w] ?= options[w] for w in options.metadata # get whatever other metadata we may have been given to begin with, just in case
  
  # check for an entry in our catalogue already
  used = _.keys metadata
  catalogued = undefined
  _findoab = () ->
    catalogued = oab_catalogue.finder metadata
    # if user wants a total refresh, don't use any of it (we still search for it though, because will overwrite later with the fresh stuff)
    if catalogued? and res.refresh isnt 0
      res.permissions ?= catalogued.permissions if catalogued.permissions? and (catalogued.metadata?.journal? or catalogued.metadata?.issn?)
      if 'oabutton' in res.sources
        res.checked.push('oabutton') if 'oabutton' not in res.checked
        if catalogued.url? # within or without refresh time, if we have already found it, re-use it
          _get metadata, catalogued.metadata
          res.cached = true if _got() # no need for further finding if we have the url and all necessary metadata
          res.url = catalogued.url
          res.found.oabutton = res.url
        else if catalogued.createdAt > Date.now() - res.refresh*86400000
          _get metadata, catalogued.metadata # it is in the catalogue but we don't have a link for it, and it is within refresh days old, so re-use the metadata from it
          res.cached = true # and cause an immediate return, we don't bother looking for everything again if we already couldn't find it within a given refresh window
  _findoab()
  
  # TODO update requests so successful ones write the source to the catalogue - but updating requests is not priority yet, so not doing right now

  if not res.cached
    # check crossref for metadata if we don't have enough, but do already have a doi
    _get_formatted_crossref = (cr) ->
      res.checked.push('crossref') if 'crossref' not in res.checked
      try
        cr ?= API.use.crossref.works.doi metadata.doi
        if cr is undefined
          if metadata.doi?
            delete options.url if options.url.indexOf('doi.org/' + metadata.doi) isnt -1
            delete metadata.doi
            delete options.doi # don't allow the user-provided data to later override if we can't validate it on crossref
        else
          try metadata.title = cr.title[0] if cr.title.length
          try metadata.doi = cr.DOI if cr.DOI?
          try metadata.doi = cr.doi if cr.doi? # just in case
          try metadata.crossref_type = cr.type
          try metadata.author = cr.author if cr.author?
          try metadata.journal = cr['container-title'][0] if cr['container-title'].length
          try metadata.issue = cr.issue if cr.issue?
          try metadata.volume = cr.volume if cr.volume?
          try metadata.page = cr.page.toString() if cr.page?
          try metadata.issn ?= cr.ISSN[0] if cr.ISSN?
          #try metadata.subject = cr.subject if cr.subject? # not sure if this is present in crossref... check anyway - commented out because getting clashes with the mapping
          try metadata.publisher = cr.publisher if cr.publisher?
          try metadata.year ?= cr['published-print']['date-parts'][0][0] if cr['published-print']['date-parts'][0][0].length
          try metadata.year ?= cr.created['date-time'].split('-')[0]
          try metadata.published = if cr['published-online']?['date-parts'] and cr['published-online']['date-parts'][0].length is 3 then cr['published-online']['date-parts'][0].join('-') else if cr['published-print']?['date-parts'] and cr['published-print']?['date-parts'][0].length is 3 then cr['published-print']['date-parts'][0].join('-') else undefined
    _get_formatted_crossref() if (not _got() or (res.find and not res.url)) and metadata.doi and 'crossref' in res.sources # crossref is usually fast and worth checking, even if just a find and the metadata is not strictly needed
  
    # check epmc if we don't have enough
    _get_formatted_europepmc = (cr) ->
      res.checked.push('epmc') if 'epmc' not in res.checked
      try
        tl = cr.toLowerCase().replace('pmc','').length > 8
        rs = if cr.indexOf('/') isnt -1 then API.use.europepmc.doi(cr) else if tl then API.use.europepmc.title(cr) else API.use.europepmc.pmc cr
        if rs?
          cr = rs
        else if not tl
          cr = API.use.europepmc.pmid cr
        try metadata.pmcid = cr.pmcid if cr.pmcid?
        try metadata.title = cr.title if cr.title?
        try metadata.doi = cr.doi if cr.doi?
        try metadata.pmid = cr.pmid if cr.pmid?
        try
          metadata.author = cr.authorList.author
          for a in metadata.author
            a.given = a.firstName
            a.family = a.lastName
            a.affiliation = [{name: a.affiliation}] if a.affiliation
        try metadata.journal ?= cr.journalInfo.journal.title if cr.journalInfo.journal.title?
        try metadata.issue = cr.journalInfo.issue if cr.journalInfo.issue?
        try metadata.volume = cr.journalInfo.volume if cr.journalInfo.volume?
        try metadata.page = cr.pageInfo.toString() if cr.pageInfo?
        try metadata.issn = cr.journalInfo.journal.issn if cr.journalInfo.journal.issn?
        #try metadata.subject = cr.subject if cr.subject? # not sure if epmc has subject
        #try metadata.publisher = cr.publisher #epmc does not appear to have publisher
        try metadata.year = cr.journalInfo.yearOfPublication if cr.journalInfo.yearOfPublication?
        try metadata.year ?= cr.journalInfo.printPublicationDate.split('-')[0]
        try 
          metadata.published ?= if cr.journalInfo.printPublicationDate.indexOf('-') isnt -1 then cr.journalInfo.printPublicationDate else if cr.electronicPublicationDate then cr.electronicPublicationDate else undefined
          delete metadata.published if metadata.published.split('-').length isnt 3
        if cr.url
          res.url = cr.url
          res.found.epmc = res.url
  
    if (not _got() or (res.find and not res.url)) and 'epmc' in res.sources and (metadata.doi or metadata.pmid or metadata.pmcid or metadata.title)
      try _get_formatted_europepmc metadata.doi ? metadata.pmcid ? metadata.pmid ? metadata.title
  
    # if no doi but do have title, try to reverse match it with crossref
    _get_reversed_crossref = () ->
      check = API.use.crossref.reverse metadata.title
      if check?.data?.doi and check.data.title? and check.data.title.length <= metadata.title.length*1.2 and check.data.title.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(check.data.title.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1
        metadata.doi = check.data.doi
        metadata.title = check.data.title
        _get_formatted_crossref(check.original.message) if check.original?.message? and 'crossref' in res.sources
      res.checked.push 'reverse'
    _get_reversed_crossref() if (not _got() or (res.find and not res.url)) and 'reverse' in res.sources and not metadata.doi? and metadata.title? and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and not options.reversed?
  
    # if still no doi, but do have title or pmid or pmc, and don't have a URL or some provided page content, try to find a URL via bing
    if (not _got() or (res.find and not res.url)) and not metadata.doi and not options.url and not content and 'bing' in res.sources and API.settings?.service?.openaccessbutton?.resolve?.bing isnt false and API.settings?.service?.openaccessbutton?.resolve?.bing?.use isnt false
      API.settings.service.openaccessbutton.resolve.bing = {max:1000,cap:'30days'} if API.settings?.service?.openaccessbutton?.resolve?.bing is true
      try
        cap = if API.settings?.service?.openaccessbutton?.resolve?.bing?.cap? then API.job.cap(API.settings.service.openaccessbutton?.resolve?.bing?.max ? 1000, API.settings.service.openaccessbutton?.resolve?.bing?.cap ? '30days','oabutton_bing') else undefined
        if cap?.capped
          res.capped = true
        else
          res.checked.push 'bing'
          mct = if metadata.title then unidecode(metadata.title.toLowerCase()).replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ') else if metadata.pmid then metadata.pmid else metadata.pmc
          bing = API.use.microsoft.bing.search mct, true, 2592000000, API.settings.use.microsoft.bing.key # search bing for what we think is a title (caching up to 30 days)
          bct = unidecode(bing.data[0].name.toLowerCase()).replace('(pdf)','').replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ')
          if not API.service.oab.blacklist(bing.data[0].url) and mct.replace(/ /g,'').indexOf(bct.replace(/ /g,'')) is 0 # if the URL is usable and tidy bing title is not a partial match to the start of the provided title, we won't do anything with it
            try
              if bing.data[0].url.toLowerCase().indexOf('.pdf') is -1 or mct.replace(/[^a-z0-9]+/g, "").indexOf(bing.data[0].url.toLowerCase().split('.pdf')[0].split('/').pop().replace(/[^a-z0-9]+/g, "")) is 0
                options.url = bing.data[0].url.replace(/"/g,'')
              else
                content = API.convert.pdf2txt(bing.data[0].url)
                content = content.substring(0,1000) if content.length > 1000
                content = content.toLowerCase().replace(/[^a-z0-9]+/g, "").replace(/\s\s+/g, '')
                if content.indexOf(mct.replace(/ /g, '')) isnt -1
                  options.url = bing.data[0].url.replace(/"/g,'')
            catch
              options.url = bing.data[0].url.replace(/"/g,'')
  
    # if we have a url or content but no doi or title yet, try scraping the url/content
    if (not _got() or (res.find and not res.url)) and not metadata.doi and not metadata.title and ((options.url and 'scrape' in res.sources) or content)
      res.checked.push 'scrape' if not content? # scrape the page if we have to - this is slow, so we hope not to do this much
      _get metadata, API.service.oab.scrape options.url, content
       # try crossref if did not already try and scrape found title but not a doi
      _get_reversed_crossref() if 'reverse' in res.sources and 'reverse' not in res.checked and not _got() and not metadata.doi? and metadata.title? and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and not options.reversed?
  
    # we can get a 404 for an article behind a loginwall if the service does not do splash pages,
    # and then we can accidentally get the article that exists called "404 not found". So we just don't
    # run checks for titles that start with 404
    # See https://github.com/OAButton/discussion/issues/931
    # this is the article: http://research.sabanciuniv.edu/34037/
    delete metadata.title if metadata.title? and (metadata.title is 404 or metadata.title.indexOf('404') is 0)
  
    # all sources that have not yet been checked, that could find us an article, are now checked in parallel
    # by this point, by default, it would be oadoi, figshare, doaj
    if (not _got() or (res.find and not res.url)) and (metadata.doi or metadata.title)
      did = 0
      _run = (src, which) ->
        try
          if not res.url or res.all
            # if using title clean it up a bit try metadata.title = metadata.title.toLowerCase().replace(/(<([^>]+)>)/g,'')
            rs = if src is 'doaj' then API.use[src].articles[which](metadata[which]) else if src is 'epmc' then API.use.europepmc[which](metadata[which]) else API.use[src][which] metadata[which]
            res.checked.push(src) if src not in res.checked
            mt = rs.title ? rs.dctitle ? rs.bibjson?.title ? rs.metadata?['oaf:result']?.title?.$
            if rs?.url and (which isnt 'title' or (mt and mt.length <= metadata.title.length*1.2 and mt.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(mt.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1))
              if rs.redirect isnt false
                res.url = if rs.redirect then rs.redirect else rs.url
                res.found[src] ?= res.url
              metadata.licence ?= rs.best_oa_location?.license if rs.best_oa_location?.license
              metadata.title ?= mt if mt?
              metadata.pmid ?= rs.pmid if rs.pmid?
              metadata.journal ?= if rs.journalInfo?.journal?.title? then rs.journalInfo.journal.title.split('(')[0].trim() else if rs.journal?.title? then rs.journal.title.split('(')[0].trim() else undefined
              metadata.issn ?= if rs.journalInfo?.journal?.issn? then rs.journalInfo.journal.issn else if rs.journal?.issn? then rs.journal.issn else undefined
        did += 1

      _prl = (src, which) -> Meteor.setTimeout (() -> _run src, which), 10
      howmany = 0
      for src in res.sources
        if res.url and not res.all
          break
        else if src not in ['oabutton','crossref','reverse','bing','scrape'] # these ones will have been checked already
          if src isnt 'epmc' or 'epmc' not in res.checked # probably has already been checked, but can check now if not
            howmany += 1
            if res.parallel
              _prl(src, 'doi') if metadata.doi?
              _prl(src, 'title') if metadata.title?
            else
              _run(src, 'doi') if metadata.doi?
              _run(src, 'title') if metadata.title?
      whiled = 0
      while res.parallel and howmany*2 isnt did and (res.all is true or not res.url) and whiled < res.sources.length*3
        whiled += 1
        future = new Future()
        Meteor.setTimeout (() -> future.return()), 500
        future.wait()
  
    # if pmcid or pmid are required and not yet found, check epmc if it was not already checked and we have since found a doi or title to lookup
    if (not _got() or (res.find and not res.url)) and 'epmc' in res.sources and 'epmc' not in res.checked and (metadata.doi or metadata.title)
      _get_formatted_europepmc metadata.doi ? metadata.title
  
    # can check DOAJ for journal and perhaps get some metadata from that
    if (not _got() or (res.find and not res.url)) and (metadata.journal or metadata.issn) and 'doaj' in res.sources
      try
        dres = API.use.doaj.journals.search(if metadata.issn then 'issn:"'+metadata.issn+'"' else 'bibjson.journal.title:"'+metadata.journal+'"')
        res.checked.push('doaj') if 'doaj' not in res.checked
        if dres?.results?.length > 0
          for ju in dres.results[0].bibjson.link
            if ju.type is 'homepage'
              _get metadata, dres.results[0].bibjson
              res.journal = ju.url
              res.found.doaj = ju.url
              break
  
  for uo in ['title','journal','year','doi'] # certain user-provided values override any that we do find ourselves - but don't include authors as that comes back more complex
    if options[uo] and options[uo].length and options[uo] isnt metadata[uo]
      res.usermetadata ?= catalogued?.usermetadata ? {}
      res.usermetadata[uo] ?= []
      res.usermetadata[uo].push {previous: metadata[uo], provided: options[uo], uid: options.uid, createdAt: Date.now()}
      metadata[uo] = options[uo] 
  for key in ['title','journal'] # tidy some metadata
    if typeof metadata[key] is 'string' and metadata[key].charAt(0).toUpperCase() isnt metadata[key].charAt(0)
      try metadata[key] = metadata[key].charAt(0).toUpperCase() + metadata[key].slice(1)

  # re-check the catalogue if we now have more metadata than we did at the initial search, so we can combine results rather than making dups
  metadata.url ?= options.url if options.url?
  if not catalogued?
    for tid in ['doi','pmid','pmcid','url','title']
      if metadata[tid] and tid not in used
        _findoab()
        break

  # fix possibly messy years
  if metadata.year?
    try
      for ms in metadata.year.split('/')
        metadata.year = ms if ms.length is 4
    try
      for md in metadata.year.split('-')
        metadata.year = md if md.length is 4
    try
      delete metadata.year if typeof metadata.year isnt 'number' and (metadata.year.length isnt 4 or metadata.year.replace(/[0-9]/gi,'').length isnt 0)
  if not metadata.year? and metadata.published?
    try
      mps = metadata.published.split('-')
      metadata.year = mps[0] if mps[0].length is 4
  if metadata.year?
    try
      delete metadata.year if typeof metadata.year isnt 'number' and (metadata.year.length isnt 4 or metadata.year.replace(/[0-9]/gi,'').length isnt 0)
    catch
      delete metadata.year
      
  # remove authors if only present as strings (end users may provide them this way which causes problems in saving and re-using them
  # and author strings are not much use for discovering articles anyway
  if metadata.author?
    delete metadata.author if typeof metadata.author is 'string'
    delete metadata.author if _.isArray metadata.author and metadata.author.length > 0 and typeof metadata.author[0] is 'string'

  metadata.url = catalogued.metadata.url if catalogued?.metadata?.url?
  metadata.url = [metadata.url] if typeof metadata.url is 'string'
  if options.url?
    metadata.url ?= []
    metadata.url.push(options.url) if options.url not in metadata.url
  res.permissions = API.service.oab.permissions(metadata) if not res.permissions?.permitted? and options.permissions and not _.isEmpty metadata
  res.test = true if JSON.stringify(metadata).toLowerCase().replace(/'/g,' ').replace(/"/g,' ').indexOf(' test ') isnt -1 #or (options.embedded? and options.embedded.indexOf('openaccessbutton.org') isnt -1)
  res.metadata = metadata
  
  delete res.url if res.url is false # we put url to the top of the response for humans using false, but remove that before saving

  # update or create a catalogue record
  if JSON.stringify(metadata) isnt '{}' and res.test isnt true
    if catalogued?
      upd = {}
      upd.url = res.url if res.url? and res.url isnt catalogued.url
      upd.metadata = metadata if not _.isEqual metadata, catalogued.metadata
      upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
      uc = _.union res.checked, catalogued.checked
      upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
      uf = _.extend(res.found, catalogued.found)
      upd.found = uf if not _.isEqual uf, catalogued.found
      upd.permissions = res.permissions if res.permissions? and not _.isEqual res.permissions, catalogued.permissions
      upd.usermetadata = res.usermetadata if res.usermetadata?
      if typeof metadata.title is 'string'
        ftm = API.service.oab.ftitle(metadata.title)
        upd.ftitle = ftm if ftm isnt catalogued.ftitle
      oab_catalogue.update(catalogued._id, upd) if not _.isEmpty upd
      res.catalogue = catalogued._id
    else
      fl = 
        url: res.url
        metadata: metadata
        sources: res.sources
        checked: res.checked
        found: res.found
        permissions: res.permissions
      fl.ftitle = API.service.oab.ftitle(metadata.title) if typeof metadata.title is 'string'
      fl.usermetadata = res.usermetadata if res.usermetadata?
      res.catalogue = oab_catalogue.insert fl

  # get ill info for instantill widget
  if res.from? and res.plugin is 'instantill'
    res.ill = {}
    try res.ill.openurl = API.service.oab.ill.openurl res.from, metadata
    try res.ill.terms = API.service.oab.ill.terms res.from
    try res.ill.subscription = API.service.oab.ill.subscription res.from, metadata, res.refresh

  # always save a new find with a new ID, so we can track all the attempts to find something, and record who did it if known
  if options.uid
    res.uid = options.uid
    res.username = options.username
    res.email = options.email
  res.started = started
  res.ended = Date.now()
  res.took = res.ended - res.started
  oab_find.insert res
  return res




