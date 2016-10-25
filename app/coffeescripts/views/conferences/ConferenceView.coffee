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
      'click .protect_recording_link':   'protect_recording_link'

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

    publish_recording: (e) ->
      e.preventDefault()
      $.ajaxJSON($(e.currentTarget).attr('href') + "/publish_recording", "POST", {
          recording_id: $(e.currentTarget).data("id"),
          publish: "true"
        }, (data) =>
          $.flashMessage I18n.t('recordings.publish_success', 'Your "publish recording" request was received. Please check back later to view its new status.')
          $(e.currentTarget).attr('disabled','disabled')
      )

    unpublish_recording: (e) ->
      e.preventDefault()
      return if !confirm(I18n.t('recordings.confirm.unpublish', "Are you sure you want to unpublish this recording?\n\nNobody will be able to see it."))
      $.ajaxJSON($(e.currentTarget).attr('href') + "/publish_recording", "POST", {
          recording_id: $(e.currentTarget).data("id"),
          publish: "false"
        }, (data) =>
          $.flashMessage I18n.t('recordings.unpublish_success', 'Your "unpublish recording" request was received. Please check back later to view its new status.')
          $(e.currentTarget).attr('disabled','disabled')
          $('a[data-id="' + $(e.currentTarget).data("id") + '"]').attr("href", "")
          $('a[data-id="' + $(e.currentTarget).data("id") + '"]').children("span").last().remove()
      )

    delete_recording: (e) ->
      e.preventDefault()
      return if !confirm(I18n.t('recordings.confirm.delete', "Are you sure you want to delete this recording?\n\nYou will not be able to reopen it."))
      $.ajaxJSON($(e.currentTarget).attr('href') + "/delete_recording", "POST", {
          recording_id: $(e.currentTarget).data("id")
        }, (data) =>
          window.location.reload(true)
      )

    protect_recording_link: (e) ->
      e.preventDefault()
      $.ajaxJSON($(e.currentTarget).attr('href') + "/protect_recording", "POST", {
          recording_id: $(e.currentTarget).data("id"),
          protect: "true"
        }, (data) =>
          window.location.reload(true)
      )

    unprotect_recording_link: (e) ->
      e.preventDefault()
      $.ajaxJSON($(e.currentTarget).attr('href') + "/protect_recording", "POST", {
          recording_id: $(e.currentTarget).data("id"),
          protect: "false"
        }, (data) =>
          window.location.reload(true)
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
