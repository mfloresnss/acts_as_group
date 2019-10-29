module ActAsGroup
  class Group
    attr_reader :ids, :type, :owner_id, :id

    def initialize(attributes)
      @id = attributes[:id] || SecureRandom.hex(14)
      @ids = attributes[:ids]&.map!(&:to_s)
      @type = attributes[:type]
      @owner_id = attributes[:owner_id].to_s
    end

    # Devuelve un hash con los atributos de esta clase
    def attributes
      {id: id, ids: ids, type: type, owner_id: owner_id}
    end

    def valid?
      !(type.blank? || owner_id.blank? || ids.blank? || id.blank?)
    end

    def eql?(other)
      self == other
    end

    def ==(other)
      id == other.id
    end

    protected

    def destroy_sync
      ids_not_removed = []

      # Destruimos el grupo, lo que quiere decir que borramos todos los elementos que
      # pertenencen a él
      documents.each do |document|
        if ActAsGroup.configuration.authorize?.call(
          document,
          :destroy,
          ActAsGroup.configuration.model_name.to_s.camelize.constantize.find(@owner_id)
        )
          destroy!(document)
        else
          ids_not_removed << document.id
        end
      end

      return ActAsGroup.configuration.process_success.call(self, :destroy) if ids_not_removed.empty?

      ActAsGroup.configuration.process_errors.call(self, ids_not_removed, :destroy)
    end

    def update_sync(attributes)
      ids_not_updated = []

      # Modificamos el grupo, lo que quiere decir que modificamos todos los elementos que
      # pertenencen a él
      documents.each do |document|
        if ActAsGroup.configuration.authorize?.call(
          document,
          :update,
          ActAsGroup.configuration.model_name.to_s.camelize.constantize.find(@owner_id)
        )
          update!(document, attributes)
        else
          ids_not_updated << document.id
        end
      end

      if ids_not_updated.empty?
        return ActAsGroup.configuration.process_success.call(self, :update, attributes)
      end

      ActAsGroup.configuration.process_errors.call(self, ids_not_updated, :update, attributes)
    end

    # Devuelve un criteria con los documentos agrupados
    def documents
      type.to_s.classify.constantize.where(id: ids)
    end

    # Update this very resource
    def update!(document, attributes)
      document.send(ActAsGroup.configuration.update_resource.to_sym, attributes)
    end

    # Remove this very resource
    def destroy!(document)
      document.send(ActAsGroup.configuration.destroy_resource.to_sym)
    end
  end
end
