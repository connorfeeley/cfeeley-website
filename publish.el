;;; publish.el --- Build cfeeley.org

;; Copyright (C) 2023 Connor Feeley <git@cfeeley.org>
;; Copyright (C) 2021, 2023 David Wilson <david@systemcrafters.net>

;; Author: David Wilson <david@systemcrafters.net>
;; Maintainer: David Wilson <david@systemcrafters.net>
;; URL: https://codeberg.org/SystemCrafters/systemcrafters.net
;; Version: 0.0.1
;; Package-Requires: ((emacs "28.2"))
;; Keywords: hypermedia, blog, feed, rss

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Docs License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Docs License for more details.
;;
;; You should have received a copy of the GNU General Docs License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Usage:
;; emacs -Q --batch -l ./publish.el --funcall dw/publish

;;; Code:

;; Initialize package sources
(require 'package)

;; Set the package installation directory so that packages aren't stored in the
;; ~/.emacs.d/elpa path.
(setq package-user-dir (expand-file-name "./.packages"))

(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("melpa-stable" . "https://stable.melpa.org/packages/")
                         ("elpa" . "https://elpa.gnu.org/packages/")))

;; Initialize the package system
(require 'use-package)

;; Require built-in dependencies
(require 'vc-git)
(require 'ox-publish)
(require 'subr-x)
(require 'cl-lib)

;; Install other dependencies
(use-package esxml
  :pin "melpa-stable"
  :ensure t)

(use-package htmlize
  :ensure t)

(use-package webfeeder
  :ensure t)

(defvar yt-iframe-format
  (concat "<div class=\"video\">"
          "  <iframe src=\"https://www.youtube.com/embed/%s\" allowfullscreen></iframe>"
          "</div>"))

(defun dw/embed-video (video-id)
  (format yt-iframe-format video-id))

(setq user-full-name "Connor Feeley")
(setq user-mail-address "git@cfeeley.org")

(defvar dw/site-url (if (string-equal (getenv "CI") "true")
                        "https://cfeeley.org"
                      "http://localhost:8080")
  "The URL for the site being generated.")

(org-link-set-parameters
 "yt"
 :follow
 (lambda (handle)
   (browse-url
    (concat "https://www.youtube.com/watch?v="
            handle)))
 :export
 (lambda (path desc backend channel)
   (when (eq backend 'html)
     (dw/embed-video path))))

(defun dw/site-header ()
  (list `(header (@ (class "site-header"))
                 (div (@ (class "container"))
                    (div (@ (class "row align-items-center justify-content-between"))
                         (div (@ (class "col-sm-12 col-md-8"))
                              (div (@ (class "site-title"))
                                   ,"Connor Feeley ~ cfeeley"))
                         (div (@ (class "col-sm col-md"))
                              (div (@ (class "site-description text-sm-left text-md-right text-lg-right text-xl-right"))
                                   ,""))))
                 (div (@ (class "site-masthead"))
                      (div (@ (class "container"))
                        (div (@ (class "row align-items-center justify-content-between"))
                          (div (@ (class "col-sm-12 col-md-12"))
                            (nav (@ (class "nav"))
                              (a (@ (class "nav-link") (href "/")) "home") " "
                              (a (@ (class "nav-link") (href "/city-stuff")) "/city stuff") " "
                              (a (@ (class "nav-link") (href "/tech")) "/tech") " "
                              (a (@ (class "nav-link") (href "/news")) "/news") " "))))))))

(defun dw/site-footer ()
  (list `(footer (@ (class "site-footer"))
                 (div (@ (class "container"))
                      (div (@ (class "row"))
                           (div (@ (class "column"))
                                (p (a (@ (href ,(concat dw/site-url "/privacy-policy/"))) "Privacy Policy")
                                   " · "
                                   (a (@ (href ,(concat dw/site-url "/credits/"))) "Credits")
                                   " · "
                                   (a (@ (href ,(concat dw/site-url "/rss/"))) "RSS Feeds"))
                             (p "© 2023 Connor Feeley | contact@cfeeley.org"))
                           )))))

(defun get-article-output-path (org-file pub-dir)
  (let ((article-dir (concat pub-dir
                             (downcase
                              (file-name-as-directory
                               (file-name-sans-extension
                                (file-name-nondirectory org-file)))))))

    (if (string-match "\\/index.org\\|\\/404.org$" org-file)
        pub-dir
        (progn
          (unless (file-directory-p article-dir)
            (make-directory article-dir t))
          article-dir))))

(defun dw/get-commit-hash ()
  "Get the short hash of the latest commit in the current repository."
  (string-trim-right
   (with-output-to-string
     (with-current-buffer standard-output
       (vc-git-command t nil nil "rev-parse" "--short" "HEAD")))))

(cl-defun dw/generate-page (title
                            content
                            info
                            &key
                            (publish-date)
                            (head-extra)
                            (pre-content)
                            (exclude-header)
                            (exclude-footer))
  (concat
   "<!DOCTYPE html>"
   (sxml-to-xml
    `(html (@ (lang "en"))
           (head
            (meta (@ (charset "utf-8")))
            (meta (@ (author "Connor Feeley")))
            (meta (@ (name "viewport")
                     (content "width=device-width, initial-scale=1, shrink-to-fit=no")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "16x16")   (target "_blank") (href "/img/favicon-16x16.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "32x32")   (target "_blank") (href "/img/favicon-32x32.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "48x48")   (target "_blank") (href "/img/favicon-48x48.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "96x96")   (target "_blank") (href "/img/favicon-96x96.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "180x180") (target "_blank") (href "/img/favicon-180x180.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "300x300") (target "_blank") (href "/img/favicon-300x300.png")))
            (link (@ (rel "icon noopener noreferrer") (type "image/png") (sizes "512x512") (target "_blank") (href "/img/favicon-512x512.png")))
            (link (@ (rel "alternative")
                     (type "application/rss+xml")
                     (title "News")
                     (href ,(concat dw/site-url "/rss/news.xml"))))
            ;; TODO: consider reenabling these fonts.
            ;; (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/fonts/iosevka-aile/iosevka-aile.css"))))
            ;; (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/fonts/jetbrains-mono/jetbrains-mono.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/css/code.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/css/site.css"))))
            (link (@ (rel "stylesheet") (href ,(concat dw/site-url "/css/prism.css"))))
            (script (@ (src "/js/prism.js"))
                    ;; Empty string to cause a closing </script> tag
                    "")
            (script (@ (defer "defer")
                       (data-goatcounter "https://stats.cfeeley.org/count")
                       (src "https://stats.cfeeley.org/count.js"))
                    ;; Empty string to cause a closing </script> tag
                    "")
            ,(when head-extra head-extra)
            (title ,(concat title " ~ cfeeley")))
           (body ,@(unless exclude-header
                     (dw/site-header))
                 (div (@ (class "container"))
                      (div (@ (class "site-post"))
                           (h1 (@ (class "site-post-title"))
                               ,title)
                           ,(when publish-date
                              `(p (@ (class "site-post-meta")) ,publish-date))
                           ,(if-let ((video-id (plist-get info :video)))
                                (dw/embed-video video-id))
                           ,(when pre-content pre-content)
                           (div (@ (id "content"))
                                (*RAW-STRING* ,content))))
             ,@(unless exclude-footer
                     (dw/site-footer)))))))

(defun dw/org-html-template (contents info)
  (dw/generate-page (org-export-data (plist-get info :title) info)
                    contents
                    info
                    :publish-date (org-export-data (org-export-get-date info "%B %e, %Y") info)))

(defun dw/org-html-link (link contents info)
  "Removes file extension and changes the path into lowercase file:// links."
  (when (and (string= 'file (org-element-property :type link))
             (string= "org" (file-name-extension (org-element-property :path link))))
    (org-element-put-property link :path
                              (downcase
                               (file-name-sans-extension
                                (org-element-property :path link)))))

  (let ((exported-link (org-export-custom-protocol-maybe link contents 'html info)))
    (cond
     (exported-link exported-link)
     ((equal contents nil)
      (format "<a href=\"%s\">%s</a>"
              (org-element-property :raw-link link)
              (org-element-property :raw-link link)))
     ((string-prefix-p "/" (org-element-property :raw-link link))
      (format "<a href=\"%s\">%s</a>"
              (org-element-property :raw-link link)
              contents))
     (t (org-export-with-backend 'html link contents info)))))

(defun dw/make-heading-anchor-name (headline-text)
  (thread-last headline-text
    (downcase)
    (replace-regexp-in-string " " "-")
    (replace-regexp-in-string "[^[:alnum:]_-]" "")))

(defun dw/org-html-headline (headline contents info)
  (let* ((text (org-export-data (org-element-property :title headline) info))
         (level (org-export-get-relative-level headline info))
         (level (min 7 (when level (1+ level))))
         (anchor-name (dw/make-heading-anchor-name text))
         (attributes (org-element-property :ATTR_HTML headline))
         (container (org-element-property :HTML_CONTAINER headline))
         (container-class (and container (org-element-property :HTML_CONTAINER_CLASS headline))))
    (when attributes
      (setq attributes
            (format " %s" (org-html--make-attribute-string
                           (org-export-read-attribute 'attr_html `(nil
                                                                   (attr_html ,(split-string attributes))))))))
    (concat
     (when (and container (not (string= "" container)))
       (format "<%s%s>" container (if container-class (format " class=\"%s\"" container-class) "")))
     (if (not (org-export-low-level-p headline info))
         (format "<h%d%s><a id=\"%s\" class=\"anchor\" href=\"#%s\">¶</a>%s</h%d>%s"
                 level
                 (or attributes "")
                 anchor-name
                 anchor-name
                 text
                 level
                 (or contents ""))
       (concat
        (when (org-export-first-sibling-p headline info) "<ul>")
        (format "<li>%s%s</li>" text (or contents ""))
        (when (org-export-last-sibling-p headline info) "</ul>")))
     (when (and container (not (string= "" container)))
       (format "</%s>" (cl-subseq container 0 (cl-search " " container)))))))

(defun dw/org-html-src-block (src-block _contents info)
  (let* ((lang (org-element-property :language src-block))
	       (code (org-html-format-code src-block info)))
    (format "<pre>%s</pre>" (string-trim code))))

(defun roygbyte/org-html-src-block (src-block _contents info)
  "Transcode a SRC-BLOCK element from Org to HTML.
  CONTENTS holds the contents of the item.  INFO is a plist holding
  contextual information."
  (if (org-export-read-attribute :attr_html src-block :textarea)
      (org-html--textarea-block src-block)
    (let* ((lang (org-element-property :language src-block))
           (code (org-html-format-code src-block info))
           (label (let ((lbl (org-html--reference src-block info t)))
                    (if lbl (format " id=\"%s\"" lbl) "")))
           (klipsify  (and  (plist-get info :html-klipsify-src)
                            (member lang '("javascript" "js"
                                           "ruby" "scheme" "clojure" "php" "html")))))
      (if (not lang) (format "<pre class=\"example\"%s>\n%s</pre>" label code)
        (format "<div class=\"org-src-container\">\n%s%s\n</div>"
                ;; Build caption.
                (let ((caption (org-export-get-caption src-block)))
                  (if (not caption) ""
                    (let ((listing-number
                           (format
                            "<span class=\"listing-number\">%s </span>"
                            (format
                             (org-html--translate "Listing %d:" info)
                             (org-export-get-ordinal
                              src-block info nil #'org-html--has-caption-p)))))
                      (format "<label class=\"org-src-name\">%s%s</label>"
                              listing-number
                              (org-trim (org-export-data caption info))))))
                ;; Contents.
                ;; Changed HTML template to work with Prism.
                (if klipsify
                    (format "<pre><code class=\"src language-%s\"%s%s>%s</code></pre>"
                            lang
                            label
                            (if (string= lang "html")
                                " data-editor-type=\"html\""
                              "")
                            code)
                  (format "<pre><code class=\"src language-%s\"%s>%s</code></pre>"
                          lang label code)))))))


(defun dw/org-html-special-block (special-block contents info)
  "Transcode a SPECIAL-BLOCK element from Org to HTML.
CONTENTS holds the contents of the block.  INFO is a plist
holding contextual information."
  (let* ((block-type (org-element-property :type special-block))
          (attributes (org-export-read-attribute :attr_html special-block)))
	  (format "<div class=\"%s center\">\n%s\n</div>"
      block-type
      (or contents
        (if (string= block-type "cta") ""
          "")))))

(org-export-define-derived-backend 'site-html 'html
  :translate-alist
  '((template . dw/org-html-template)
    (link . dw/org-html-link)
    (src-block . roygbyte/org-html-src-block)
    (special-block . dw/org-html-special-block)
    (headline . dw/org-html-headline))
  :options-alist
  '((:video "VIDEO" nil nil)))

(defun org-html-publish-to-html (plist filename pub-dir)
  "Publish an org file to HTML, using the FILENAME as the output directory."
  (let ((article-path (get-article-output-path filename pub-dir)))
    (cl-letf (((symbol-function 'org-export-output-file-name)
               (lambda (extension &optional subtreep pub-dir)
                 ;; The 404 page is a special case, it must be named "404.html"
                 (concat article-path
                         (if (string= (file-name-nondirectory filename) "404.org") "404" "index")
                         extension))))
      (org-publish-org-to 'site-html
                          filename
                          (concat "." (or (plist-get plist :html-extension)
                                          "html"))
                          plist
                          article-path))))

(setq org-publish-use-timestamps-flag t
      org-publish-timestamp-directory "./.org-cache/"
      org-export-with-section-numbers nil
      org-export-use-babel nil
      org-export-with-smart-quotes t
      org-export-with-sub-superscripts nil
      org-export-with-tags 'not-in-toc
      org-html-htmlize-output-type 'css
      org-html-prefer-user-labels t
      org-html-link-home dw/site-url
      org-html-link-use-abs-url t
      org-html-link-org-files-as-html t
      org-html-html5-fancy t
      org-html-self-link-headlines t
      org-export-with-toc nil
      make-backup-files nil)

(defun cf/format-sitemap-entry (entry style project)
  "Format posts with author and published data in the index page."
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][%s]] - %s · %s"
                 entry
                 (org-publish-find-title entry project)
                 (car (org-publish-find-property entry :author project))
                 (format-time-string "%B %d, %Y"
                                     (org-publish-find-date entry project))))
        ((eq style 'tree) (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun dw/format-news-entry (entry style project)
  "Format posts with author and published data in the index page."
  (cond ((not (directory-name-p entry))
         (format "[[file:%s][%s]] - %s · %s"
                 entry
                 (org-publish-find-title entry project)
                 (car (org-publish-find-property entry :author project))
                 (format-time-string "%B %d, %Y"
                                     (org-publish-find-date entry project))))
        ((eq style 'tree) (file-name-nondirectory (directory-file-name entry)))
        (t entry)))

(defun dw/news-sitemap (title files)
  (format "#+title: %s\n\n%s"
          title
          (mapconcat (lambda (file)
                       (format "- %s\n" file))
                     (cadr files)
                     "\n")))

(defun dw/rss-extract-title (html-file)
  "Extract the title from an HTML file."
  (with-temp-buffer
    (insert-file-contents html-file)
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (dom-text (car (dom-by-class dom "site-post-title"))))))

(defun dw/rss-extract-date (html-file)
  "Extract the post date from an HTML file."
  (with-temp-buffer
    (insert-file-contents html-file)
    (let* ((dom (libxml-parse-html-region (point-min) (point-max)))
           (date-string (dom-text (car (dom-by-class dom "site-post-meta"))))
           (parsed-date (parse-time-string date-string))
           (day (nth 3 parsed-date))
           (month (nth 4 parsed-date))
           (year (nth 5 parsed-date)))
      ;; NOTE: Hardcoding this at 8am for now
      (encode-time 0 0 8 day month year))))

;(defun dw/rss-extract-summary (html-file)
;  )

(setq webfeeder-title-function #'dw/rss-extract-title
      webfeeder-date-function #'dw/rss-extract-date)

(setq org-publish-project-alist
      (list '("cfeeley:main"
              :recursive t
              :base-directory "./content"
              :base-extension "org"
              :publishing-directory "./public"
              :publishing-function org-html-publish-to-html
              :auto-sitemap t
              :sitemap-filename "./sitemap.org"
              :sitemap-title "Main"
              :sitemap-format-entry cf/format-sitemap-entry
              ;; :sitemap-style list
              ;; :sitemap-function dw/news-sitemap
              :sitemap-sort-files anti-chronologically
              :with-title nil
              :with-timestamps nil)
            '("cfeeley:faq"
              :base-directory "./content/faq"
              :base-extension "org"
              :publishing-directory "./public/faq"
              :publishing-function org-html-publish-to-html
              :with-title nil
              :with-timestamps nil)
            '("cfeeley:assets"
              :base-directory "./assets"
              :base-extension "css\\|js\\|png\\|jpg\\|gif\\|pdf\\|mp3\\|ogg\\|woff2\\|ttf"
              :publishing-directory "./public"
              :recursive t
              :publishing-function org-publish-attachment)
            '("cfeeley:news"
              :base-directory "./content/news"
              :base-extension "org"
              :publishing-directory "./public/news"
              :publishing-function org-html-publish-to-html
              :auto-sitemap t
              :sitemap-filename "../news.org"
              :sitemap-title "News"
              :sitemap-format-entry dw/format-news-entry
              :sitemap-style list
              ;; :sitemap-function dw/news-sitemap
              :sitemap-sort-files anti-chronologically
              :with-title nil
              :with-timestamps nil)))

;; TODO: Generate a _redirects file instead once Codeberg Pages releases a new version
(defun dw/generate-redirects (redirects)
  (dolist (redirect redirects)
    (let ((output-path (concat "./public/" (car redirect) "/index.html"))
          (redirect-url (concat dw/site-url "/" (cdr redirect) "/")))
      (make-directory (file-name-directory output-path) t)
      (with-temp-file output-path
        (insert
         (dw/generate-page "Redirecting..."
                           (concat "You are being redirected to "
                                   "<a href=\"" redirect-url "\">" redirect-url "</a>")
                           '()
                           :head-extra
                           (concat "<meta http-equiv=\"refresh\" content=\"0; url='" redirect-url "'\"/>")))))))

(defun dw/publish ()
  "Publish the entire site."
  (interactive)
  (org-publish-all (string-equal (or (getenv "FORCE")
                                     (getenv "CI"))
                                 "true"))

  (webfeeder-build "rss/news.xml"
                   "./public"
                   dw/site-url
                   (let ((default-directory (expand-file-name "./public/")))
                     (remove "news/index.html"
                             (directory-files-recursively "news"
                                                          ".*\\.html$")))
                   :builder 'webfeeder-make-rss
                   :title "cfeeley.org feed"
                   :description "Latest updates from cfeeley.org"
                   :author "Connor Feeley")

  (dw/generate-redirects '())

  ;; Copy the domains file to ensure the custom domain resolves
  (copy-file ".domains" "public/.domains" t)
)

(provide 'publish)
;;; publish.el ends here
