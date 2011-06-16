class Array
  def extract_options!
    if last.is_a?(Hash) && last.extractable_options?
      pop
    else
      {}
    end
  end # def
end # Array

