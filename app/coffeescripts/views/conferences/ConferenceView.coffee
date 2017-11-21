#
# Copyright (C) 2014 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

define [
  'i18n!conferences'
  'jquery'
  'Backbone'
  'jst/conferences/newConference'
  'str/htmlEscape'
  'jquery.google-analytics'
  'compiled/jquery.rails_flash_notifications'
], (I18n, $, {View}, template, htmlEscape) ->

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
      'click .delete_recording_link': 'delete_recording'

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
        if curIndex > 0
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
      if link_text == loading_text
        return

      $self.text(loading_text)
      $.ajaxJSON($self.attr('href'), 'GET', {}, (data) ->
        $self.text(link_text)
        if data.length == 0
          $.flashError(I18n.t('no_urls_error', "Sorry, it looks like there aren't any %{type} pages for this conference yet.", {type: $self.attr('name')}))
        else if data.length > 1
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

    delete_recording: (e) ->
      return if !confirm(I18n.t('recordings.confirm.delete', "Are you sure you want to delete this recording?"))
      e.preventDefault()
      $parent = $(e.currentTarget).parent()
      params = {recording_id: $parent.data("id")}
      this.toggleActionButton($parent, {state: "processing", action: "delete"})
      this.toggleRecordingLink($parent, {state: "processing"})
      $.ajaxJSON($parent.data('url') + "/delete_recording", "POST", params,
        (data) =>
          if data.deleted
            this.removeRecordingRow($parent)
            return
          this.ensure_delete_performed($parent)
      )

    ensure_delete_performed: ($parent, attempt = 1) ->
      $.ajaxJSON($parent.data('url') + "/recording", "POST", {
          recording_id: $parent.data("id"),
        }, (data) =>
          if $.isEmptyObject(data)
            this.removeRecordingRow($parent)
            return
          if attempt < 5
            attempt += 1
            setTimeout((=> this.ensure_delete_performed($parent, attempt); return;), attempt * 1000)
            return
          $.flashError(I18n.t('conferences.recordings.action_error', "Sorry, the action performed on this recording failed. Try again later"))
          this.toggleActionButton($parent, {state: "processed", action: "delete"})
          this.toggleRecordingLink($parent, {state: "processed"})
      )

    toggleActionButton: ($parent, data) ->
      button = $('.ig-button[data-id="' + $parent.data("id") + '"][data-action="' + data.action + '"]')
      spinner = $('.ig-loader[data-id="' + $parent.data("id") + '"][data-action="' + data.action + '"]')
      if data.state == 'processing'
        button.hide()
        spinner.show()
        return
      spinner.hide()
      button.show()

    toggleRecordingLink: ($parent, data) ->
      link = $('a[data-id="' + $parent.data("id") + '"]')
      if data.state == 'processing'
          link.bind 'click', ->
            return false
          return
      link.unbind 'click'

    removeRecordingRow: ($parent) ->
      row = $('.ig-row[data-id="' + $parent.data("id") + '"]')
      list = $(row.parent().parent())
      if list.children().length == 1
        container = $(list.parent())
        container.remove()
        return
      list_element = $(row.parent())
      list_element.remove()
