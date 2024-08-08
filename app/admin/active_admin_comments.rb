ActiveAdmin.register ActiveAdmin::Comment do
  menu parent: 'Content'

  permit_params do
    %i[body]
  end
end