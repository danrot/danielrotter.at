SITE_FOLDER=site
DIST_FOLDER=dist
URL=https://danielrotter.at

STYLES=${DIST_FOLDER}/style.css
ROBOTS=${DIST_FOLDER}/robots.txt
PAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${addsuffix .html,${basename ${filter-out ${SITE_FOLDER}/404.md,${wildcard ${SITE_FOLDER}/*.md}}}}}
POSTS=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${addsuffix .html,${basename ${wildcard ${SITE_FOLDER}/*/*/*/*.md}}}}
IMAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${filter-out ${SITE_FOLDER}/images/posts,${wildcard ${SITE_FOLDER}/images/*}}}
POSTS_IMAGES=${patsubst ${SITE_FOLDER}/%,${DIST_FOLDER}/%,${wildcard ${SITE_FOLDER}/images/posts/*}}
DESCRIPTION=A blog about web development in general and about PHP, JavaScript, Linux and its command line in particular.
INDEX_HTML=dist/index.html
INDEX_MD =dist/index.md
SITEMAP_XML=dist/sitemap.xml
FEED_XML=dist/feed.xml
MASTER_TEMPLATE=templates/master.html

.PHONY: mkdir
.SUFFIXES:
SHELL=/bin/bash -ex

website: ${STYLES} ${ROBOTS} ${PAGES} ${POSTS} ${IMAGES} ${POSTS_IMAGES} ${INDEX_HTML} dist/sitemap.xml dist/feed.xml dist/404.html

${INDEX_HTML}: ${POSTS} ${PAGES} ${MASTER_TEMPLATE}
	[ ! -f ${INDEX_MD} ] || rm ${INDEX_MD}
	[ ! -f ${INDEX_HTML} ] || rm ${INDEX_HTML}
	echo '## Blog posts' >> ${INDEX_MD}
	for file in $$(echo "${POSTS}" | tr ' ' '\n' | sort -r) ; do \
		date=$$(rg --only-matching "<time style=\"[^\"]*\" datetime=\"([^\"]+)\" pubdate" $$file -r '$$1') ; \
		title=$$(rg --only-matching "<h1 style=\"[^\"]*\">([^<]+)" $$file -r '$$1') ; \
		tags=$$(rg --only-matching --multiline '</h1>\s*<div style=\"[^\"]*\">([^<]*)</div>' $$file -r '$$1') ; \
		echo "- <time style=\"view-transition-name: time-$$date\" datetime=\"$$date\">$$date</time>: [<span style=\"view-transition-name: title-$$date\">$$title</span>]($${file#${DIST_FOLDER}}) (<span style=\"view-transition-name: tags-$$date\">$$tags<span>)" >> ${INDEX_MD} ; \
	done
	echo '' >> ${INDEX_MD}
	echo '## Slash pages' >> ${INDEX_MD}
	for file in $$(echo "${PAGES}" | tr ' ' '\n' | sort) ; do \
		title=$$(rg --only-matching "<h1>([^<]+)" $$file -r '$$1') ; \
		excerpt=$$(rg --only-matching "<meta name=\"description\" content=\"([^\"]+)\"" $$file -r '$$1') ; \
		echo "- [<span style=\"view-transition-name: time-$$date\">$$title<span>]($${file#${DIST_FOLDER}}): $$excerpt" >> ${INDEX_MD} ; \
	done
	pandoc \
		--template ${MASTER_TEMPLATE} \
		--wrap=none \
		-M excerpt='${DESCRIPTION}' \
		-M url=${URL} \
		--output ${INDEX_HTML} \
		${INDEX_MD}
	rm ${INDEX_MD}

${SITEMAP_XML}: ${POSTS} ${PAGES}
	[ ! -f ${SITEMAP_XML} ] || rm ${SITEMAP_XML}
	touch ${SITEMAP_XML}
	echo '<?xml version="1.0" encoding="UTF-8"?>' >> ${SITEMAP_XML}
	echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' >> ${SITEMAP_XML}

	for file in $$(echo "${POSTS}" | tr ' ' '\n') ; do \
		lastmodifieddate=$$(rg --only-matching "<time style=\"[^\"]*\" datetime=\"([^\"]+)\">" $$file -r '$$1' || echo '') ; \
		[ -z "$${lastmodifieddate}" ] && lastmodifieddate=$$(rg --only-matching "<time style=\"[^\"]*\" datetime=\"([^\"]+)\" pubdate" $$file -r '$$1') ; \
		echo '<url>' >> ${SITEMAP_XML} ; \
		echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
		echo "<lastmod>$$lastmodifieddate</lastmod>" >> ${SITEMAP_XML} ; \
		echo '</url>' >> ${SITEMAP_XML} ; \
	done

	echo '<url>' >> ${SITEMAP_XML} ; \
	echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
	echo '</url>' >> ${SITEMAP_XML} ; \

	for file in $$(echo "${PAGES}" | tr ' ' '\n') ; do \
		echo '<url>' >> ${SITEMAP_XML} ; \
		echo "<loc>${URL}$${file#${DIST_FOLDER}}</loc>" >> ${SITEMAP_XML} ; \
		echo '</url>' >> ${SITEMAP_XML} ; \
	done

	echo '</urlset>' >> ${SITEMAP_XML}

${FEED_XML}: ${POSTS}
	[ ! -f ${FEED_XML} ] || rm ${FEED_XML}
	touch ${FEED_XML}

	echo '<?xml version="1.0" encoding="UTF-8"?>' >> ${FEED_XML}
	echo '<feed xml:lang="en">' >> ${FEED_XML}
	echo '<link href="https://danielrotter.at/feed.xml" rel="self" type="application/atom+xml"/>' >> ${FEED_XML}
	echo '<link href="https://danielrotter.at/" rel="alternate" type="text/html" hreflang="en"/>' >> ${FEED_XML}
	echo "<updated>$$(date +%Y-%m-%d)</updated>" >> ${FEED_XML}
	echo "<id>${URL}/feed.xml</id>" >> ${FEED_XML}
	echo '<title type="html">Daniel Rotter</title>' >> ${FEED_XML}
	echo "<subtitle>${DESCRIPTION}</subtitle>" >> ${FEED_XML}

	for file in $$(echo "${POSTS}" | tr ' ' '\n' | sort -r) ; do \
		url=${URL}/$${file#${DIST_FOLDER}} ; \
		title=$$(rg --only-matching "<h1 style=\"[^\"]*\">([^<]+)" $$file -r '$$1') ; \
		published=$$(rg --only-matching "<time style=\"[^\"]*\" datetime=\"([^\"]+)\" pubdate" $$file -r '$$1') ; \
		updated=$$(rg --only-matching "<time datetime=\"([^\"]+)\">" $$file -r '$$1' || echo '') ; \
		[ -z "$${updated}" ] && updated=$$published ; \
		tags=$$(rg --only-matching --multiline '</h1>\s*<div style=\"[^\"]*\">([^<]*)</div>' $$file -r '$$1') ; \
		excerpt=$$(rg --only-matching "<meta name=\"description\" content=\"([^\"]+)\"" $$file -r '$$1') ; \
		echo '<entry>' >> ${FEED_XML} ; \
		echo "<title type=\"html\">$$title</title>" >> ${FEED_XML} ; \
		echo "<link href=\"$$url\" rel=\"alternate\" type=\"text/html\" title=\"$$title\"/>" >> ${FEED_XML} ; \
		echo "<published>$$published</published>" >> ${FEED_XML} ; \
		echo "<updated>$$updated</updated>" >> ${FEED_XML} ; \
		echo "<id>$$url</id>" >> ${FEED_XML} ; \
		for tag in $$(echo "$$tags" | tr ' ' '\n' | tr -d ',') ; do \
			echo "<category term=\"$$tag\"/>" >> ${FEED_XML} ; \
		done ; \
		echo "<summary type=\"html\">$$excerpt</summary>" >> ${FEED_XML} ; \
		echo '</entry>' >> ${FEED_XML} ; \
	done

	echo '</feed>' >> ${FEED_XML}

${DIST_FOLDER}/%.html: ${SITE_FOLDER}/%.md ${MASTER_TEMPLATE}
	[ -d $(@D) ] || mkdir -p $(@D)
	pandoc \
		--template ${MASTER_TEMPLATE} \
		--wrap=none \
		-M date=${subst /,-,${patsubst %/,%,${patsubst ${DIST_FOLDER}/%,%,${dir $@}}}} \
		-M url=${URL}/${patsubst ${DIST_FOLDER}/%,%,$@} \
		--output $@ $<

${DIST_FOLDER}/%.css: ${SITE_FOLDER}/%.css
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/%.txt: ${SITE_FOLDER}/%.txt
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/images/posts/%: ${SITE_FOLDER}/images/posts/%
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

${DIST_FOLDER}/images/%: ${SITE_FOLDER}/images/%
	[ -d $(@D) ] || mkdir -p $(@D)
	cp $< $@

clean:
	rm -r ${DIST_FOLDER}
