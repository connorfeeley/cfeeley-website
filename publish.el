(require 'package)
(package-initialize)
(setq package-archives '(("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ("melpa" . "https://melpa.org/packages/")))
(setq package-user-dir (expand-file-name "./.packages"))
(package-refresh-contents)
(dolist (pkg '(dash projectile yaml-mode htmlize ox-rss))
  (unless (package-installed-p pkg)
    (package-install pkg)))

(require 'dash)
(require 'org)

(require 'ox-rss)
(require 'ox-publish)
(require 'projectile)

(defun cfeeley--pre/postamble-format (name)
  "Formats the pre/postamble named NAME by reading a file from the snippets directory."
  `(("en" ,(with-temp-buffer
             (insert-file-contents (expand-file-name (format "%s.html" name) "./snippets"))
             (buffer-string)))))

(defun cfeeley--insert-snippet (filename)
  "Format the snippet named FILENAME by reading a file from the snippets directory."
  (with-temp-buffer
    (insert-file-contents (expand-file-name filename "./snippets"))
    (buffer-string)))

(defun cfeeley/org-publish-sitemap--valid-entries (entries)
  "Filter ENTRIES that are not valid or skipped by the sitemap entry function."
  (-filter (lambda (x) (car x)) entries))

(defun cfeeley/latest-posts-sitemap-function (title sitemap)
  "posts.org generation. Only publish the latest 5 posts from SITEMAP (https://orgmode.org/manual/Sitemap.html).  Skips TITLE."
  (let* ((posts (cdr sitemap))
         (posts (cfeeley/org-publish-sitemap--valid-entries posts))
         (last-five (seq-subseq posts 0 (min (length posts) 5))))
    (org-list-to-org (cons (car sitemap) last-five))))

(defun cfeeley/archive-sitemap-function (title sitemap)
  "archive.org page (Blog full post list). Wrapper to skip TITLE and just use LIST (https://orgmode.org/manual/Sitemap.html)."
  (let* ((title "Blog") (subtitle "Archive")
         (posts (cdr sitemap))
         (posts (cfeeley/org-publish-sitemap--valid-entries posts)))
    (concat (format "#+TITLE: %s\n\n* %s\n" title subtitle)
            (org-list-to-org (cons (car sitemap) posts))
            "\n#+BEGIN_EXPORT html\n<a href='rss.xml'><i class='fa fa-rss'></i></a>\n#+END_EXPORT\n")))

(defun cfeeley/archive-sitemap-format-entry (entry style project)
  "archive.org and posts.org (latest) entry formatting. Format sitemap ENTRY for PROJECT with the post date before the link, to generate a posts list.  STYLE is not used."
  (let* ((base-directory (plist-get (cdr project) :base-directory))
         (filename (expand-file-name entry (expand-file-name base-directory (cfeeley/project-root))))
         (draft? (cfeeley/post-get-metadata-from-frontmatter filename "DRAFT")))
    (unless (or (equal entry "404.org") draft?)
      (format "%s [[file:%s][%s]]"
              (format-time-string "<%Y-%m-%d>" (org-publish-find-date entry project))
              entry
              (org-publish-find-title entry project)))))

(defun cfeeley/sitemap-for-rss-sitemap-function (title sitemap)
  "Publish rss.org which needs each entry as a headline."
  (let* ((title "Blog") (subtitle "Archive")
         (posts (cdr sitemap))
         (posts (cfeeley/org-publish-sitemap--valid-entries posts)))
    (concat (format "#+TITLE: %s\n\n" title)
            (org-list-to-generic
             posts
             (org-combine-plists
              (list :splice t
                    :istart nil
                    :icount nil
                    :dtstart " " :dtend " "))))))

(defun cfeeley/sitemap-for-rss-sitemap-format-entry (entry style project)
  "Format ENTRY for rss.org for excusive use of exporting to RSS/XML. Each entry needs to be a headline. STYLE is not used."
  (let* ((base-directory (plist-get (cdr project) :base-directory))
         (filename (expand-file-name entry (expand-file-name base-directory (cfeeley/project-root))))
         (title (cfeeley/post-get-metadata-from-frontmatter filename "TITLE"))
         ;;(title (org-publish-format-file-entry "%t" filename project))
         ;;(title (org-publish-find-title filename project))
         (date (format-time-string "<%Y-%m-%d>" (org-publish-find-date entry project)))
         (draft? (cfeeley/post-get-metadata-from-frontmatter filename "DRAFT")))
    (unless (or (equal entry "404.org") draft?)
      (with-temp-buffer
        (org-mode)
        (insert (format "* [[file:%s][%s]]\n" entry title))
        (org-set-property "RSS_PERMALINK" (concat "posts/" (file-name-sans-extension entry) ".html"))
        (org-set-property "RSS_TITLE" title)
        (org-set-property "PUBDATE" date)
        ;; to avoid second update to rss.org by org-icalendar-create-uid
        ;;(insert-file-contents entry)
        (buffer-string)))))

(defun cfeeley/org-html-timestamp (timestamp contents info)
  "We are not going to leak org mode silly <date> format when rendering TIMESTAMP to the world, aren't we?.  CONTENTS and INFO are passed down to org-html-timestamp."
  (let ((org-time-stamp-custom-formats
       '("%d %b %Y" . "%d %b %Y %H:%M"))
        (org-display-custom-times 't))
    (org-html-timestamp timestamp contents info)))

(defun org-custom-link-img-export (path desc format)
  (cond
   ((eq format 'html)
    (format "<figure><img class=\"image-export\" src=\"%s\" alt=\"%s\"/></figure>" path desc))))

(org-add-link-type "img" 'org-custom-link-img-follow 'org-custom-link-img-export)

; We derive our own backend in order to override the timestamp format of the html backend
(org-export-define-derived-backend 'cfeeley/html 'html
  :translate-alist
  '((timestamp . cfeeley/org-html-timestamp)))

(defun cfeeley/post-get-metadata-from-frontmatter (post-filename key)
  "Extract the KEY as`#+KEY:` from POST-FILENAME."
  (let ((case-fold-search t))
    (with-temp-buffer
      (insert-file-contents post-filename)
      (goto-char (point-min))
      (ignore-errors
        (progn
          (search-forward-regexp (format "^\\#\\+%s\\:\s+\\(.+\\)$" key))
          (match-string 1))))))

(defun cfeeley/org-html-publish-generate-redirect (plist filename pub-dir)
  "Generate redirect files in PUB-DIR from the #+REDIRECT_FROM header in FILENAME, using PLIST."
  (let* ((redirect-from (cfeeley/post-get-metadata-from-frontmatter filename "REDIRECT_FROM"))
         (root (projectile-project-root))
         (pub-root (concat root "public"))
         (new-filepath (file-relative-name filename pub-dir))
         (deprecated-filepath (concat pub-root redirect-from))
         (target-url (concat (file-name-sans-extension new-filepath) ".html"))
         (project (cons 'redirect plist))
         (title (org-publish-find-title filename project)))
    (when redirect-from
      (with-temp-buffer
        (insert (format "This page was moved. [[file:%s][Click here if you are not yet redirected]]." new-filepath))
        (make-directory (file-name-directory deprecated-filepath) :parents)
        (let ((plist (append plist
                             (list :html-head-extra
                                   (format "<meta http-equiv='refresh' content='10; url=%s'>" target-url)))))
          (org-export-to-file 'cfeeley/html deprecated-filepath nil nil nil nil plist))))))

(defun cfeeley/head-common-list (plist)
  "List of elements going in head for all pages.  Takes PLIST as context."
  (let ((description "Connor Feeley's blog."))
    (list
     (list "link" (list "href" "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.1.1/css/all.min.css" "rel" "stylesheet" "integrity" "sha512-KfkfwYDsLkIlwQp6LFnl8zNdLGxu9YAA1QvwINks4PhcElQSvqcyVLLD9aMhXd13uQjoXtEKNosOWaZqXgel0g==" "crossorigin" "anonymous"))
     (list "meta" (list "description" description))
     (list "link" (list "rel" "alternate" "type" "application+rss/xml" "title" description "href" "posts/rss.xml")))))

(defun cfeeley/hash-for-filename (filename)
  "Returns the sha25 for FILENAME."
  (with-temp-buffer
    (insert-file-contents filename)
    (secure-hash 'sha256 (current-buffer))))

(defun cfeeley/asset-relative-link-to (resource pub-dir &optional versioned)
    (let* ((assets-project (assoc "assets" org-publish-project-alist 'string-equal))
           (dst-asset (expand-file-name resource (org-publish-property :publishing-directory assets-project)))
           (asset-relative-to-dst-file (file-relative-name dst-asset pub-dir)))
      (if versioned
          (format "%s?v=%s" asset-relative-to-dst-file
                  (cfeeley/hash-for-filename (expand-file-name resource (projectile-project-root))))
        dst-asset asset-relative-to-dst-file)))

(defun cfeeley/org-html-publish-to-html (plist filename pub-dir)
  "Analog to org-html-publish-to-html using cfeeley/html backend.  PLIST, FILENAME and PUB-DIR are passed as is."
  (plist-put plist :html-head
             (concat
               (cfeeley--insert-snippet "analytics.js")
               (cfeeley/org-html-head
                (append (cfeeley/head-common-list plist)
                        (plist-get plist :html-head-list)) plist)))
  (plist-put plist :html-htmlized-css-url (cfeeley/asset-relative-link-to "css/site.css" pub-dir t))
  (cfeeley/org-html-publish-generate-redirect plist filename pub-dir)
  (org-publish-org-to 'cfeeley/html filename
		      (concat "." (or (plist-get plist :html-extension)
				      org-html-extension
				      "html"))
		      plist pub-dir))

(defun cfeeley/org-html-head (tags plist)
  "Generate header elements from TAGS.  Accept PLIST for extra context."
  (mapconcat (lambda (x)
               (let ((tag (nth 0 x))
                     (attrs (nth 1 x)))
                 (format "<%s %s/>" tag
                         (mapconcat
                          (lambda (x)
                            (let ((attr (nth 0 x))
                                  (value (nth 1 x)))
                              (when x
                                (format "%s='%s'" attr value)))) (seq-partition attrs 2) " ")))) tags "\n"))

(defun cfeeley/org-html-publish-post-to-html (plist filename pub-dir)
  "Wraps org-html-publish-to-html.  Append post date as subtitle to PLIST.  FILENAME and PUB-DIR are passed."
  (let ((project (cons 'blog plist)))
    (plist-put plist :subtitle
               (format-time-string "%b %d, %Y" (org-publish-find-date filename project)))
    (cfeeley/org-html-publish-to-html plist filename pub-dir)))

(defun cfeeley/project-root ()
  "Thin (zero) wrapper over projectile to find project root."
  (projectile-project-root))

(defun cfeeley/project-relative-filename (filename)
  "Return the relative path of FILENAME to the project root."
  (file-relative-name filename (cfeeley/project-root)))

(defun cfeeley/org-html-publish-site-to-html (plist filename pub-dir)
  "Wraps org-html-publish-to-html.  Append css to hide title to PLIST and other front-page styles.  FILENAME and PUB-DIR are passed."
  (when (equal "index.org" (cfeeley/project-relative-filename filename))
    (plist-put plist :html-head-list
               (list
                (list "link"
                      (list "rel" "stylesheet" "href" (cfeeley/asset-relative-link-to "css/index.css" pub-dir t))))))
  (cfeeley/org-html-publish-to-html plist filename pub-dir))

(defun cfeeley/org-rss-publish-to-rss (plist filename pub-dir)
  "Wrap org-rss-publish-to-rss with PLIST and PUB-DIR, publishing only when FILENAME is 'archive.org'."
  (if (equal "rss.org" (file-name-nondirectory filename))
      (org-rss-publish-to-rss plist filename pub-dir)))

; Project definition
(defvar cfeeley--publish-project-alist
  (list
   ;; generates the main site, and as side-effect, the sitemap for the latest 5 posts
   (list "blog"
         :base-directory "./posts"
         :exclude (regexp-opt '("posts.org" "archive.org" "rss.org"))
         :base-extension "org"
         :recursive t
         :publishing-directory (expand-file-name "public/posts" (projectile-project-root))
         :publishing-function 'cfeeley/org-html-publish-post-to-html
         :section-numbers nil
         :with-toc nil
         :html-preamble t
         :html-preamble-format (cfeeley--pre/postamble-format 'preamble)
         :html-postamble t
         :html-postamble-format (cfeeley--pre/postamble-format 'postamble)
         :html-head-include-scripts nil
         :html-head-include-default-style nil
         :auto-sitemap t
         :sitemap-filename "posts.org"
         :sitemap-style 'list
         :sitemap-title nil
         :sitemap-sort-files 'anti-chronologically
         :sitemap-function 'cfeeley/latest-posts-sitemap-function
         :sitemap-format-entry 'cfeeley/archive-sitemap-format-entry)
   (list "archive"
         :base-directory "./posts"
         :recursive t
         :exclude (regexp-opt '("posts.org" "archive.org" "rss.org"))
         :base-extension "org"
         :publishing-directory "./public"
         :publishing-function 'ignore
         ;;:publishing-function 'cfeeley/org-rss-publish-to-rss
         :html-link-home "http://mac-vicar.eu/"
         :html-link-use-abs-url t
         :auto-sitemap t
         :sitemap-style 'list
         :sitemap-filename "archive.org"
         :sitemap-sort-files 'anti-chronologically
         :sitemap-function 'cfeeley/archive-sitemap-function
         :sitemap-format-entry 'cfeeley/archive-sitemap-format-entry)
   ;; Generate a org sitemap to use later for rss, ignoring publishing the site again
   (list "sitemap-for-rss"
         :base-directory "./posts"
         :recursive t
         :exclude (regexp-opt '("posts.org" "archive.org" "rss.org"))
         :base-extension "org"
         :publishing-directory "./public"
         :publishing-function 'ignore
         :auto-sitemap t
         :sitemap-style 'list
         :sitemap-filename "rss.org"
         :sitemap-function 'cfeeley/sitemap-for-rss-sitemap-function
         :sitemap-format-entry 'cfeeley/sitemap-for-rss-sitemap-format-entry)
   ;; generates the rss.xml file from the rss sitemap
   (list "rss"
         :base-directory "./"
         :recursive t
         :exclude "."
         :include '("posts/rss.org")
         :exclude (regexp-opt '("posts.org" "archive.org" "rss.org"))
         :base-extension "org"
         :publishing-directory "./public"
         :publishing-function 'cfeeley/org-rss-publish-to-rss
         :html-link-home "http://mac-vicar.eu/"
         :html-link-use-abs-url t)
   (list "site"
         :base-directory "./"
         :include '("posts/archive.org" "README.org")
         :base-extension "org"
         :publishing-directory (expand-file-name "public" (projectile-project-root))
         :publishing-function 'cfeeley/org-html-publish-site-to-html
         :section-numbers nil
         :html-preamble t
         :html-preamble-format (cfeeley--pre/postamble-format 'preamble)
         :html-postamble t
         :html-postamble-format (cfeeley--pre/postamble-format 'postamble)
         :html-validation-link nil
         :html-head-include-scripts nil
         :html-head-include-default-style nil)
   (list "tutorials"
         :base-directory "./tutorials"
         :base-extension "org"
         :recursive t
         :publishing-directory "./public/tutorials"
         :publishing-function 'org-html-publish-to-html
         :section-numbers nil
         :with-toc t)
   (list "assets"
         :base-directory "./"
         :exclude (regexp-opt '("assets" "public"))
         :include '("CNAME" "keybase.txt" "LICENSE" ".nojekyll" "publish.el" ".well-known/nostr.json")
         :recursive t
         :base-extension (regexp-opt '("jpg" "gif" "png" "js" "svg" "css"))
         :publishing-directory "./public"
         :publishing-function 'org-publish-attachment)))

; Our publishing definition
(defun cfeeley-publish-all ()
  "Publish the blog to HTML."
  (interactive)
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((dot . t) (plantuml . t)))
  (let ((make-backup-files nil)
        (org-publish-project-alist       cfeeley--publish-project-alist)
        ;; deactivate cache as it does not take the publish.el file into account
        (user-full-name "Connor Feeley")
        (user-mail-address "contact@cfeeley.org")
        (org-src-fontify-natively t)
        (org-publish-cache nil)
        (org-publish-use-timestamps-flag nil)
        (org-publish-timestamp-directory "./.org-cache/")
        (org-export-with-section-numbers nil)
        (org-export-with-smart-quotes    t)
        (org-export-with-toc             nil)
        (org-export-with-sub-superscripts '{})
        (org-html-divs '((preamble  "header" "preamble")
                         (content   "main"   "content")
                         (postamble "footer" "postamble")))
        (org-html-container-element         "section")
        (org-html-metadata-timestamp-format "%d %b. %Y")
        (org-html-checkbox-type             'html)
        (org-html-html5-fancy               t)
        (org-html-validation-link           nil)
        (org-html-doctype                   "html5")
        (org-entities-user
         (quote
          (("faArchive" "\\faArchive" nil "<i aria-hidden='true' class='fa fa-archive'></i>" "" "" "")
           ("faRss" "\\faRss" nil "<i aria-hidden='true' class='fa fa-rss'></i>" "" "" "")
           ("faBookmark" "\\faBookmark" nil "<i aria-hidden='true' class='fa fa-bookmark'></i>" "" "" "")
           ("faCode" "\\faCode" nil "<i aria-hidden='true' class='fa fa-code'></i>" "" "" "")
           ("faBike" "\\faBike" nil "<i aria-hidden='true' class='fa fa-bicycle'></i>" "" "" "")
           ("faToronto" "\\faBike" nil "<i aria-hidden='true' class='fa fa-train-subway'></i>" "" "" "")
           ("faGithub" "\\faGithub" nil "<i aria-hidden='true' class='fa fa-github'></i>" "" "" "")
           ("faGraduationCap" "\\faGraduationCap" nil "<i aria-hidden='true' class='fa fa-graduation-cap'></i>" "" "" "")
           ("faImage" "\\faImage" nil "<i aria-hidden='true' class='fa fa-image'></i>" "" "" ""))))
        (org-html-htmlize-output-type       'css)
        (org-plantuml-jar-path (-first 'file-exists-p
                                       ; openSUSE, Ubuntu
                                       '("/usr/share/java/plantuml.jar" "/usr/share/plantuml/plantuml.jar")))
        (org-confirm-babel-evaluate
         (lambda (lang body)
           (message (format "in lambda %s" lang))
           (not (member lang '("dot" "plantuml"))))))
    (org-publish-all)))

(provide 'publish)
;;; publish.el ends here


