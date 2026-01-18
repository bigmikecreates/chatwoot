class ConfigLoader
  DEFAULT_OPTIONS = {
    config_path: nil,
    reconcile_only_new: true
  }.freeze

  def process(options = {})
    options = DEFAULT_OPTIONS.merge(options)

    @reconcile_only_new = options[:reconcile_only_new]

    @config_path = options[:config_path].presence
    @config_path ||= Rails.root.join('config')

    reconcile_general_config
    reconcile_feature_config
  end

  def general_configs
    @config_path ||= Rails.root.join('config')
    @general_configs ||= YAML.safe_load(
      File.read("#{@config_path}/installation_config.yml")
    ).freeze
  end

  private

  def account_features
    @account_features ||= YAML.safe_load(
      File.read("#{@config_path}/features.yml")
    ).freeze
  end

  def reconcile_general_config
    general_configs.each do |config|
      new_config = config.with_indifferent_access
      existing_config = InstallationConfig.find_by(name: new_config[:name])
      save_general_config(existing_config, new_config)
    end
  end

  def save_general_config(existing, latest)
    if existing
      save_as_new_config(latest) if !@reconcile_only_new && compare_values(existing, latest)
    else
      save_as_new_config(latest)
    end
  end

  def compare_values(existing, latest)
    existing.value != latest[:value] ||
      (!latest[:locked].nil? && existing.locked != latest[:locked])
  end

  def save_as_new_config(latest)
    config = InstallationConfig.find_or_initialize_by(name: latest[:name])
    config.value  = latest[:value]
    config.locked = latest[:locked]
    config.save!
  end

  def reconcile_feature_config
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')

    if config
      existing = normalize_feature_array(config.value)
      incoming = normalize_feature_array(account_features)
      return if existing == incoming

      compare_and_save_feature(config)
    else
      save_as_new_config(
        name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
        value: account_features,
        locked: true
      )
    end
  end

  def compare_and_save_feature(config)
    existing = normalize_feature_array(config.value)
    incoming = normalize_feature_array(account_features)

    features =
      if @reconcile_only_new
        (existing + incoming)
          .uniq { |h| h['name'] }
      else
        (incoming + existing)
          .uniq { |h| h['name'] }
      end

    config.update!(
      name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS',
      value: features,
      locked: true
    )
  end

  def normalize_feature_array(value)
    Array(value)
      .compact
      .select { |v| v.is_a?(Hash) }
      .map(&:stringify_keys)
      .reject { |h| h['name'].blank? }
  end
end