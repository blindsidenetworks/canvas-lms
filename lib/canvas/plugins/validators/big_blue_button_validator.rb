#
# Copyright (C) 2011 Instructure, Inc.
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
#

module Canvas::Plugins::Validators::BigBlueButtonValidator
  def self.validate(settings, plugin_setting)
    if settings.map(&:last).all?(&:blank?)
      {}
    else
      expected_settings = [:domain, :secret, :recording_enabled, :recording_options, :recording_option_enabled, :invitations_enabled]
      if settings.size != expected_settings.size || settings[:domain].blank? || settings[:secret].blank?
        plugin_setting.errors.add(:base, I18n.t('canvas.plugins.errors.all_fields_required', 'All fields are required'))
        false
      else
        settings.slice!(*expected_settings)
        settings[:recording_enabled] = Canvas::Plugin.value_to_boolean(settings[:recording_enabled])
        if settings[:recording_enabled]
          settings[:recording_option_enabled] = settings[:recording_options]=='1' ? Canvas::Plugin.value_to_boolean(settings[:recording_option_enabled]) : false
          settings[:invitations_enabled] = Canvas::Plugin.value_to_boolean(settings[:invitations_enabled])
        else
          settings[:recording_options] = '1'
          settings[:recording_option_enabled] = false
          settings[:invitations_enabled] = false
        end
        settings
      end
    end
  end
end
