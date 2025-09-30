--// Sigma Spy 自定义远程响应
--// 返回的 *table* 将被解包作为响应
--// 如果返回值是函数，传入的参数也会传递给该函数

return {
	-- [game.ReplicatedStorage.Remotes.HelloWorld] = {
	-- 	Method = "FireServer",
	-- 	Return = {"来自 Sigma Spy 的问候世界！"}
	-- }
	-- [game.ReplicatedStorage.Remotes.DepsoIsCool] = {
	-- 	Method = "FireServer",
	-- 	Return = function(OriginalFunc, ...)
	--		return {"Depso", "太棒了！"}
	-- end
	-- }
}
