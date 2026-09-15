Rails.application.routes.draw do
  # ---- Xác thực ----------------------------------------------------------
  devise_for :users,
             controllers: { sessions: "users/sessions", passwords: "users/passwords" },
             path: "",
             path_names: {
               sign_in: "dang-nhap", sign_out: "dang-xuat", password: "quen-mat-khau"
             },
             skip: [:registrations]

  get   "loi-moi/:token", to: "invitations#show",   as: :invitation
  patch "loi-moi/:token", to: "invitations#update"

  # ---- Tổng quan ---------------------------------------------------------
  root "dashboard#show"

  get "tim-kiem", to: "search#index", as: :search

  # ---- Dự án -------------------------------------------------------------
  resources :projects, path: "du-an", param: :code do
    member do
      patch :archive
      patch :unarchive
    end
    resources :tasks, path: "cong-viec", only: [:index, :create], param: :code
    get "kanban",      to: "boards#show",             as: :board
    get "thu-chi",     to: "project_transactions#index", as: :transactions
    get "thanh-vien",  to: "project_members#index",   as: :members
    get "hoat-dong",   to: "project_activities#index", as: :activities

    resources :board_columns, path: "cot", only: [:create, :update, :destroy] do
      collection { patch :reorder }
    end
    resources :project_memberships, path: "thanh-vien", only: [:create, :destroy]
  end

  # ---- Công việc ---------------------------------------------------------
  resources :tasks, path: "cong-viec", param: :code, except: [:index] do
    member do
      patch :move
      patch :quick_update
    end
    collection { patch :bulk_update }
    resources :subtasks, path: "viec-con", only: [:create, :update, :destroy]
  end

  get "viec-cua-toi", to: "my_tasks#index", as: :my_tasks

  # ---- Bình luận ---------------------------------------------------------
  resources :comments, path: "binh-luan", only: [:create, :update, :destroy]

  # ---- Thu chi -----------------------------------------------------------
  resources :transactions, path: "thu-chi" do
    collection { get :export }
  end

  # ---- Thành viên & quản trị --------------------------------------------
  resources :members, path: "thanh-vien", only: [:index, :show, :update] do
    collection { post :invite }
    member do
      post  :resend_invitation
      patch :disable
      patch :enable
    end
  end

  resources :activities, path: "hoat-dong", only: [:index]

  resource :profile, path: "ho-so", only: [:show, :update], controller: "profile" do
    patch :password, on: :collection
    patch :notifications, on: :collection
  end

  resource :settings, path: "cai-dat", only: [:show, :update], controller: "settings" do
    resources :transaction_categories, path: "danh-muc", only: [:create, :update, :destroy]
  end

  resources :notifications, path: "thong-bao", only: [:index] do
    member do
      get   :open   # đánh dấu đã đọc rồi mở đối tượng
      patch :read
    end
    collection { patch :read_all }
  end

  # ---- Cây định hướng ----------------------------------------------------
  resources :strategy_trees, path: "dinh-huong", param: :slug, except: [:edit] do
    resources :strategy_nodes, path: "nut", only: [:create, :update, :destroy] do
      member do
        patch :move
        post  :duplicate
        post  :suggest      # ✨ AI gợi ý nhánh con
        post  :apply_suggestions
      end
      collection { post :bulk_paste }
    end
    resources :strategy_snapshots, path: "phien-ban", only: [:index, :create, :destroy] do
      member { post :restore }
    end
    member do
      get :export_markdown
    end
  end

  # ---- Vận hành ----------------------------------------------------------
  get "up", to: "rails/health#show", as: :rails_health_check
end
