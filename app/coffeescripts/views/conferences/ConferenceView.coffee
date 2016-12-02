define [
  'i18n!conferences'
  'jquery'
  'Backbone'
  'jst/conferences/newConference'
  'jquery.google-analytics'
  'compiled/jquery.rails_flash_notifications'
], (I18n, $, {View}, template) ->

  class ConferenceView extends View

    tagName: 'li'

    className: 'conference'

    template: template

    events:
      'click .edit_conference_link': 'edit'
      'click .delete_conference_link': 'delete'
      'click .close_conference_link': 'close'
      'click .start-button': 'start'
      'click .external_url': 'external'
      'click .publish_recording_link': 'publish_recording'
      'click .unpublish_recording_link': 'unpublish_recording'
      'click .delete_recording_link': 'delete_recording'
      'click .protect_recording_link':   'protect_recording'
      'click .unprotect_recording_link':   'unprotect_recording'
      'mouseenter .btn.btn-small.publish' : 'mouse_enter_publish'
      'mouseleave .btn.btn-small.publish' : 'mouse_leave_publish'
      'mouseenter .btn.btn-small.protect' : 'mouse_enter_protect'
      'mouseleave .btn.btn-small.protect' : 'mouse_leave_protect'

    initialize: ->
      super
      @model.on('change', @render)

    edit: (e) ->
      # refocus if edit not finalized
      @$el.find('.al-trigger').focus()

    delete: (e) ->
      e.preventDefault()
      if !confirm I18n.t('confirm.delete', "Are you sure you want to delete this conference?")
        $(e.currentTarget).parents('.inline-block').find('.al-trigger').focus()
      else
        currentCog = $(e.currentTarget).parents('.inline-block').find('.al-trigger')[0]
        allCogs = $('#content .al-trigger').toArray()
        # Find the preceeding cog
        curIndex = allCogs.indexOf(currentCog)
        if (curIndex > 0)
          allCogs[curIndex - 1].focus()
        else
          $('.new-conference-btn').focus()
        @model.destroy success: =>
          $.screenReaderFlashMessage(I18n.t('Conference was deleted'))

    close: (e) ->
      e.preventDefault()
      return if !confirm(I18n.t('confirm.close', "Are you sure you want to end this conference?\n\nYou will not be able to reopen it."))
      $.ajaxJSON($(e.currentTarget).attr('href'), "POST", {}, (data) =>
        window.router.close(@model)
      )

    start: (e) ->
      if @model.isNew()
        e.preventDefault()
        return

      w = window.open(e.currentTarget.href, '_blank')
      if (!w) then return
      e.preventDefault()

      w.onload = () ->
        window.location.reload(true)

      # cross-domain
      i = setInterval(() ->
        if (!w) then return
        try
          href = w.location.href
        catch e
          clearInterval(i)
          window.location.reload(true)
      , 100)

    external: (e) ->
      # TODO: kill this if it's not in use anywhere
      $.trackEvent('Conference', 'External URL')
      e.preventDefault()
      loading_text = I18n.t('loading_urls_message', "Loading, please wait...")
      $self = $(e.currentTarget)
      link_text = $self.text()
      if (link_text == loading_text)
        return

      $self.text(loading_text)
      $.ajaxJSON($self.attr('href'), 'GET', {}, (data) ->
        $self.text(link_text)
        if (data.length == 0)
          $.flashError(I18n.t('no_urls_error', "Sorry, it looks like there aren't any %{type} pages for this conference yet.", {type: $self.attr('name')}))
        else if (data.length > 1)
          $box = $(document.createElement('DIV'))
          $box.append($("<p />").text(I18n.t('multiple_urls_message', "There are multiple %{type} pages available for this conference. Please select one:", {type: $self.attr('name')})))
          for datum in data
            $a = $("<a />", {href: datum.url || $self.attr('href') + '&url_id=' + datum.id, target: '_blank'})
            $a.text(datum.name)
            $box.append($a).append("<br>")

          $box.dialog(
            width: 425,
            minWidth: 425,
            minHeight: 215,
            resizable: true,
            height: "auto",
            title: $self.text()
          )
        else
          window.open(data[0].url)
      )
    publish_recording: (e) ->
      e.preventDefault()
      parent = $(e.currentTarget).parent()
      this.displaySpinner($(e.currentTarget))
      $.ajaxJSON(parent.data('url') + "/publish_recording", "POST", {
          recording_id: parent.data("id"),
          publish: "true"
        }, (data) =>
          this.togglePublishButton(parent, data.published)
          this.toggleRecordingLink(data, parent)
      )

    unpublish_recording: (e) ->
      e.preventDefault()
      parent = $(e.currentTarget).parent()
      this.displaySpinner($(e.currentTarget))
      $.ajaxJSON(parent.data('url') + "/publish_recording", "POST", {
          recording_id: parent.data("id"),
          publish: "false"
        }, (data) =>
          this.togglePublishButton(parent, data.published)
          this.toggleRecordingLink(data, parent)
      )

    delete_recording: (e) ->
      e.preventDefault()
      parent = $(e.currentTarget).parent()
      return if !confirm(I18n.t('recordings.confirm.delete', "Are you sure you want to delete this recording?\n\nYou will not be able to reopen it."))
      $.ajaxJSON(parent.data('url') + "/delete_recording", "POST", {
          recording_id: parent.data("id")
        }, (data) =>
          window.location.reload(true)
      )

    protect_recording: (e) ->
      e.preventDefault()
      parent = $(e.currentTarget).parent()
      $.ajaxJSON(parent.data('url') + "/protect_recording", "POST", {
          recording_id: parent.data("id"),
          protect: "true"
        }, (data) =>
          window.location.reload(true)
      )

    unprotect_recording: (e) ->
      e.preventDefault()
      parent = $(e.currentTarget).parent()
      $.ajaxJSON(parent.data('url') + "/protect_recording", "POST", {
          recording_id: parent.data("id"),
          protect: "false"
        }, (data) =>
          window.location.reload(true)
      )

    mouse_enter_publish: (e) ->
      elem = $(e.currentTarget)
      if elem.data("publish")
        elem.removeClass('icon-publish')
        elem.addClass('icon-unpublish unpublish_recording_link')
        elem.text('Unpublish')
      else
        elem.removeClass('icon-unpublish')
        elem.addClass('icon-publish publish_recording_link')
        elem.text('Publish')

    mouse_leave_publish: (e) ->
      elem = $(e.currentTarget)
      if elem.data("publish")
        elem.removeClass('icon-unpublish unpublish_recording_link')
        elem.addClass('icon-publish')
        elem.text('Published')
      else
        elem.removeClass('icon-publish publish_recording_link')
        elem.addClass('icon-unpublish')
        elem.text('Unpublished')

    mouse_enter_protect: (e) ->
      elem = $(e.currentTarget)
      if elem.data("protect")
        elem.removeClass('icon-lock')
        elem.addClass('icon-unlock unprotect_recording_link')
        elem.text('Unprotect')
      else
        elem.removeClass('icon-unlock')
        elem.addClass('icon-lock protect_recording_link')
        elem.text('Protect')

    mouse_leave_protect: (e) ->
      elem = $(e.currentTarget)
      if elem.data("protect")
        elem.removeClass('icon-unlock unprotect_recording_link')
        elem.addClass('icon-lock')
        elem.text('Protected')
      else
        elem.removeClass('icon-lock protect_recording_link')
        elem.addClass('icon-unlock')
        elem.text('Unprotected')

    ## FRONT END STUFF

    displaySpinner: (elem) ->
      elem.parent().find('img.loader').show()
      elem.remove()

    togglePublishButton: (parent, published) ->
      img = parent.find('img.loader')
      elem =  if published == "true"
                class: 'btn btn-small publish icon-publish'
                text: 'Published'
                publish: 'true'
              else
                class: 'btn btn-small publish icon-unpublish'
                text: 'Unpublished'
                publish: 'false'
      img.hide()
      $('<a class="'+elem.class+'" data-publish="'+elem.publish+'">'+I18n.t(elem.text)+'</a>').insertAfter(img)

    toggleRecordingLink: (data, parent) ->
      thumbnails = $('.recording-thumbnails[data-id="' + parent.data("id") + '"]')
      link = $('a[data-id="' + parent.data("id") + '"]')
      ext_icon = link.children("span").last()
      if data.published == "true"
        link.attr("href", data.url)
        ext_icon.show()
        thumbnails.show()
      else
        link.attr("href", "")
        ext_icon.hide()
        thumbnails.hide()
