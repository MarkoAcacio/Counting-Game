local Directory = {}

-- Services
Directory.ReplicatedStorage = game:GetService("ReplicatedStorage")
Directory.PlayerService = game:GetService("Players")
Directory.TweenService = game:GetService("TweenService")
Directory.ContentProvider = game:GetService("ContentProvider")
Directory.MarketPlaceService = game:GetService("MarketplaceService")
Directory.StarterGui = game:GetService("StarterGui")
Directory.SoundService = game:GetService("SoundService")
Directory.GroupService = game:GetService("GroupService")
Directory.AvatarService = game:GetService("AvatarEditorService")
Directory.RunService = game:GetService("RunService")
Directory.UserInputService = game:GetService("UserInputService")
Directory.SocialService = game:GetService("SocialService")
Directory.Lighting = game:GetService("Lighting")

-- Folders
Directory.Modules = Directory.ReplicatedStorage:WaitForChild("Modules")
Directory.Events = Directory.ReplicatedStorage:WaitForChild("Events")
Directory.SoundsFolder = Directory.SoundService:WaitForChild("Sounds")
Directory.MusicFolder = Directory.SoundsFolder:WaitForChild("Music")
Directory.SFXFolder = Directory.SoundsFolder:WaitForChild("SFX")
Directory.DeathSFXFolder = Directory.SFXFolder:WaitForChild("DeathFX")
Directory.BillboardFolder = Directory.StarterGui:WaitForChild("Billboards")
Directory.CasesFolder = game.Workspace:WaitForChild("Lobby"):WaitForChild("Models"):WaitForChild("Chest_Cases")

-- Events
Directory.SFXEvent = Directory.Events:WaitForChild("SFXEvent")
Directory.MusicEvent = Directory.Events:WaitForChild("MusicEvent")
Directory.GachaEvent = Directory.Events:WaitForChild("GachaUI")
Directory.EmoteEvent = Directory.Events:WaitForChild("EmoteEvent")
Directory.ProductEvent = Directory.Events:WaitForChild("ProductEvent")
Directory.TimerEvent = Directory.Events:WaitForChild("TimerEvent")
Directory.InitEvent = Directory.Events:WaitForChild("InitEvent")
Directory.ChestEvent = Directory.Events:WaitForChild("ChestEvent")    
Directory.DailyEvent = Directory.Events:WaitForChild("DailyEvent")
Directory.NotificationEvent = Directory.Events:WaitForChild("NotificationEvent")
Directory.ProductEvent = Directory.Events:WaitForChild("ProductEvent")
Directory.PromptEvent = Directory.Events:WaitForChild("PromptEvent")
Directory.ButtonEvent = Directory.Events:WaitForChild("ButtonEvent")
Directory.DailyEvent = Directory.Events:WaitForChild("DailyEvent")
Directory.EmoteChange = Directory.Events:WaitForChild("EmoteChange")
Directory.EmoteRequest = Directory.Events:WaitForChild("EmoteRequest")
Directory.CurrencyEvent = Directory.Events:WaitForChild("CurrencyEvent")
Directory.SaveEmoteSlot = Directory.Events:WaitForChild("SaveEmoteSlot")
Directory.CaseRequest = Directory.Events:WaitForChild("CaseRequest")
Directory.ToggleAFK = Directory.Events:WaitForChild("ToggleAFK")
Directory.EquipDeath = Directory.Events:WaitForChild("EquipDeath")
Directory.DeathEvent = Directory.Events:WaitForChild("DeathEvent")
Directory.EquipCount = Directory.Events:WaitForChild("EquipCount")
Directory.CountEvent = Directory.Events:WaitForChild("CountEvent")
Directory._CaseOpen = Directory.Events:WaitForChild("_CaseOpen")
Directory.EquippedRequest = Directory.Events:WaitForChild("EquippedRequest")
Directory.RoundEvent = Directory.Events:WaitForChild("RoundEvent")
Directory.EmoteSound = Directory.Events:WaitForChild("EmoteSound")
Directory.ToggleAFKEvent = Directory.Events:WaitForChild("ToggleAFKEvent")
Directory.DisableClick = Directory.Events:WaitForChild("disableClick")
Directory.UpdateInventory = Directory.Events:WaitForChild("UpdateInventory")
Directory.CaseOpen = Directory.Events:WaitForChild("CaseOpen")

Directory.VerifyEvent = Directory.Events:WaitForChild("VerifyEvent")  -- Verifies Item Ownership
Directory.InventoryEvent = Directory.Events:WaitForChild("InventoryEvent") -- Sends Inventory Data

-- Variables

Directory.localPlayer = Directory.PlayerService.LocalPlayer

-- Tweens
Directory.HoverInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)


return Directory
