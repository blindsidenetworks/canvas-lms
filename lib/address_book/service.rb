module AddressBook
  class Service < AddressBook::Base
    def known_users(users, options={})
      return [] if users.empty?

      # start with users I know directly
      user_ids = users.map{ |user| Shard.global_id_for(user) }
      common_contexts = Services::AddressBook.common_contexts(@sender, user_ids)

      if options[:include_context]
        # add users any admin over the specified context knows indirectly
        admin_contexts = Services::AddressBook.roles_in_context(options[:include_context], user_ids)
        merge_common_contexts(common_contexts, admin_contexts)
      end

      # whitelist just those users I know
      whitelist, unknown = user_ids.partition{ |id| common_contexts.has_key?(id) }
      if unknown.present? && options[:conversation_id]
        conversation = Conversation.find(options[:conversation_id])
        participants = conversation.conversation_participants.where(user_id: [@sender, *unknown]).pluck(:user_id)
        if participants.include?(@sender.id)
          # add conversation participants to whitelist
          whitelist |= participants.map{ |id| Shard.global_id_for(id) }
        end
      end

      # apply whitelist to provided user objects/ids, to restore order
      users.select!{ |user| whitelist.include?(Shard.global_id_for(user)) }

      # if we didn't start with objects, hydrate
      users = hydrate(users) unless users.first.is_a?(User)

      # cache and return
      cache_contexts(users, common_contexts)
      users
    end

    def known_in_context(context, is_admin=false)
      # just query, hydrate, and cache
      user_ids, common_contexts = Services::AddressBook.known_in_context(@sender, context, is_admin)
      users = hydrate(user_ids)
      cache_contexts(users, common_contexts)
      users
    end

    def count_in_context(context)
      Services::AddressBook.count_in_context(@sender, context)
    end

    class Bookmarker
      def initialize
        @cursors = {}
        @more = false
      end

      def update(user_ids, cursors)
        @cursors = Hash[user_ids.zip(cursors)]
        @more = !!@cursors[user_ids.last]
      end

      def more?
        @more
      end

      def bookmark_for(user)
        @cursors[user.global_id]
      end

      def validate(bookmark)
        bookmark.is_a?(Integer) && bookmark >= 0
      end
    end

    def search_users(options={})
      bookmarker = Bookmarker.new
      BookmarkedCollection.build(bookmarker) do |pager|
        # include bookmark info in service call if necessary
        service_options = { per_page: pager.per_page }
        if pager.current_bookmark
          if pager.include_bookmark
            # don't raise the exception; there's no place better to handle it
            # than here. handling it is just complaining in an error report,
            # and then ignoring
            Canvas::Errors.capture(RuntimeError.new(
              "AddressBook::Service#search_users should not be paged with include_bookmark: true"
            ))
          end
          service_options[:cursor] = pager.current_bookmark
        end

        # query, hydrate, and cache
        user_ids, common_contexts, cursors = Services::AddressBook.search_users(@sender, options, service_options)
        bookmarker.update(user_ids, cursors)
        users = hydrate(user_ids)
        cache_contexts(users, common_contexts)

        # place results in pager
        pager.replace(users)
        pager.has_more! if bookmarker.more?
        pager
      end
    end

    def preload_users(users)
      # make sure we're dealing with user objects
      users = hydrate(users) unless users.first.is_a?(User)

      # query only those directly known, but all are "whitelisted" for caching
      global_user_ids = users.map(&:global_id)
      common_contexts = Services::AddressBook.common_contexts(@sender, global_user_ids)
      cache_contexts(users, common_contexts)
    end

    private

    # these three methods simplify merging the results of independent service
    # calls that each give back a hash like:
    #   {
    #     user_id => {
    #       courses: { course_id => roles, ... },
    #       groups: { group_id => roles, ... }
    #     },
    #     ...
    #   }
    # modifies the left hash in place, merging the data from the right into it
    def merge_common_contexts(left, right)
      right.each do |user_id,common_contexts|
        left[user_id] ||= { courses: {}, groups: {} }
        merge_common_contexts_one(left[user_id], common_contexts)
      end
    end

    def merge_common_contexts_one(left, right)
      merge_common_contexts_half(left[:courses], right[:courses])
      merge_common_contexts_half(left[:groups], right[:groups])
    end

    def merge_common_contexts_half(left, right)
      right.each do |context_id,roles|
        left[context_id] ||= []
        left[context_id] |= roles
      end
    end

    # takes a list of global user ids and returns a corresponding list of
    # objects, order preserved.
    def hydrate(ids)
      hydrated = User.select(::MessageableUser::SELECT).where(id: ids)
      reverse_lookup = hydrated.index_by(&:global_id)
      ids.map{ |id| reverse_lookup[id] }.compact
    end

    # caches with common contexts for each user in the list, pulling the
    # results from the provided array, defaulting to empty hashes (none, but
    # user still whitelisted)
    def cache_contexts(users, common_contexts)
      users.each do |user|
        contexts = common_contexts[user.global_id]
        courses = contexts ? contexts[:courses] : {}
        groups = contexts ? contexts[:groups] : {}
        @cache.store(user, courses, groups)
      end
    end
  end
end
