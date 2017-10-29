class Hash
  def compact
    delete_if { |k, v| v.nil? || v == [] }
  end
end
