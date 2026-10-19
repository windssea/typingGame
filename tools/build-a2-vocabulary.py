"""Build our independently curated A1–A2 game bank, not an official exam list."""
import json
from pathlib import Path

TOPICS = {
    "animals": ("动物与自然", "cat 猫|dog 狗|bird 鸟|fish 鱼|duck 鸭子|cow 奶牛|pig 猪|hen 母鸡|ant 蚂蚁|bee 蜜蜂|bat 蝙蝠|bear 熊|lion 狮子|tiger 老虎|horse 马|sheep 绵羊|goat 山羊|rabbit 兔子|mouse 老鼠|monkey 猴子|elephant 大象|dolphin 海豚|whale 鲸鱼|snake 蛇|spider 蜘蛛|butterfly 蝴蝶|insect 昆虫|pet 宠物|wild 野生的|zoo 动物园"),
    "food": ("美食补给", "egg 鸡蛋|rice 米饭|soup 汤|cake 蛋糕|milk 牛奶|tea 茶|jam 果酱|nut 坚果|salt 盐|meat 肉|bread 面包|cheese 奶酪|butter 黄油|yogurt 酸奶|chicken 鸡肉|beef 牛肉|salad 沙拉|sandwich 三明治|pizza 披萨|pasta 意大利面|potato 土豆|tomato 番茄|carrot 胡萝卜|onion 洋葱|bean 豆子|apple 苹果|banana 香蕉|grape 葡萄|lemon 柠檬|juice 果汁"),
    "school": ("校园探险", "pen 钢笔|book 书|desk 课桌|bag 包|art 美术|map 地图|test 测验|page 页|read 阅读|write 写|learn 学习|study 研习|lesson 课程|class 班级|teacher 老师|student 学生|pencil 铅笔|ruler 尺子|rubber 橡皮|paper 纸|notebook 笔记本|homework 家庭作业|subject 学科|science 科学|history 历史|maths 数学|library 图书馆|college 学院|answer 回答|question 问题"),
    "home": ("温馨小屋", "bed 床|door 门|wall 墙|roof 屋顶|room 房间|bath 浴缸|lamp 台灯|sofa 沙发|cup 杯子|bowl 碗|plate 盘子|spoon 勺子|fork 叉子|knife 餐刀|table 桌子|chair 椅子|window 窗户|floor 地板|kitchen 厨房|bedroom 卧室|bathroom 浴室|garden 花园|garage 车库|blanket 毯子|pillow 枕头|mirror 镜子|shelf 架子|fridge 冰箱|carpet 地毯|stairs 楼梯"),
    "family": ("朋友与家人", "mum 妈妈|dad 爸爸|son 儿子|aunt 阿姨|uncle 叔叔|baby 婴儿|girl 女孩|boy 男孩|man 男人|woman 女人|mother 母亲|father 父亲|sister 姐妹|brother 兄弟|cousin 堂表亲|daughter 女儿|parent 家长|family 家庭|friend 朋友|child 孩子|children 孩子们|people 人们|person 人|adult 成年人|guest 客人|neighbour 邻居|name 名字|age 年龄|birthday 生日|married 已婚的"),
    "travel": ("旅行出发", "bus 公交车|car 汽车|taxi 出租车|bike 自行车|boat 小船|ship 轮船|trip 短途旅行|road 道路|stop 车站|way 路线|train 火车|plane 飞机|airport 机场|station 车站|ticket 票|passport 护照|suitcase 行李箱|journey 旅程|travel 旅行|holiday 假期|hotel 酒店|tour 游览|guide 向导|beach 海滩|island 岛屿|bridge 桥|traffic 交通|bicycle 自行车|motorbike 摩托车|underground 地铁"),
    "sport": ("运动赛场", "run 跑步|swim 游泳|jump 跳跃|kick 踢|hit 击打|win 获胜|race 比赛|ball 球|team 队伍|club 俱乐部|game 游戏|sport 运动|football 足球|tennis 网球|basketball 篮球|baseball 棒球|volleyball 排球|badminton 羽毛球|cycling 骑行|skating 滑冰|skiing 滑雪|sailing 帆船运动|fishing 钓鱼|player 运动员|match 竞赛|score 得分|goal 进球|prize 奖品|winner 获胜者|exercise 锻炼"),
    "clothes": ("换装派对", "hat 帽子|cap 鸭舌帽|coat 外套|shoe 鞋|sock 袜子|boot 靴子|belt 腰带|ring 戒指|wear 穿着|size 尺码|shirt 衬衫|skirt 裙子|dress 连衣裙|jacket 夹克|jeans 牛仔裤|trousers 长裤|shorts 短裤|sweater 毛衣|uniform 制服|gloves 手套|scarf 围巾|suit 西装|pocket 口袋|button 纽扣|watch 手表|glasses 眼镜|umbrella 雨伞|fashion 时尚|cotton 棉|wool 羊毛"),
    "weather": ("天气森林", "sun 太阳|sky 天空|air 空气|ice 冰|fog 雾|snow 雪|rain 雨|wind 风|hot 热的|cold 冷的|warm 暖和的|cool 凉爽的|dry 干燥的|wet 潮湿的|cloud 云|storm 暴风雨|weather 天气|sunny 晴朗的|windy 有风的|cloudy 多云的|spring 春季|summer 夏季|autumn 秋季|winter 冬季|season 季节|river 河流|lake 湖泊|sea 海|forest 森林|mountain 山"),
    "town": ("城市寻宝", "shop 商店|bank 银行|park 公园|town 城镇|city 城市|farm 农场|hill 小山|path 小路|land 陆地|area 区域|street 街道|market 市场|museum 博物馆|cinema 电影院|theatre 剧院|hospital 医院|school 学校|cafe 咖啡馆|restaurant 餐馆|supermarket 超市|building 建筑|village 村庄|centre 中心|square 广场|corner 街角|factory 工厂|office 办公室|police 警察|church 教堂|castle 城堡"),
    "body": ("健康能量", "arm 手臂|leg 腿|eye 眼睛|ear 耳朵|lip 嘴唇|hand 手|head 头|hair 头发|face 脸|foot 脚|nose 鼻子|mouth 嘴|tooth 牙齿|teeth 牙齿们|finger 手指|stomach 胃|shoulder 肩膀|neck 脖子|knee 膝盖|back 背部|heart 心脏|health 健康|healthy 健康的|doctor 医生|nurse 护士|medicine 药|ill 生病的|pain 疼痛|rest 休息|sleep 睡觉"),
    "hobbies": ("快乐兴趣", "sing 唱歌|song 歌曲|band 乐队|film 电影|draw 画画|paint 绘画|dance 跳舞|play 玩耍|fun 乐趣|toy 玩具|music 音乐|piano 钢琴|guitar 吉他|drum 鼓|violin 小提琴|concert 音乐会|camera 相机|photo 照片|picture 图画|drawing 绘画作品|hobby 爱好|comic 漫画|magazine 杂志|story 故事|poem 诗|puzzle 谜题|chess 国际象棋|collect 收集|album 相册|festival 节庆"),
    "actions": ("行动任务", "go 去|do 做|see 看见|get 得到|put 放置|sit 坐|cut 剪|buy 买|pay 付款|ask 询问|give 给予|take 拿取|make 制作|help 帮助|find 找到|keep 保持|open 打开|close 关闭|start 开始|finish 完成|choose 选择|bring 带来|carry 搬运|catch 接住|follow 跟随|listen 听|speak 说话|remember 记住|understand 理解|practise 练习"),
    "feelings": ("心情彩虹", "good 好的|bad 坏的|nice 友好的|kind 和善的|safe 安全的|busy 忙碌的|easy 容易的|hard 困难的|slow 缓慢的|fast 快速的|happy 开心的|sad 难过的|angry 生气的|tired 疲倦的|hungry 饥饿的|thirsty 口渴的|afraid 害怕的|excited 兴奋的|bored 无聊的|quiet 安静的|loud 响亮的|friendly 友善的|careful 小心的|clever 聪明的|brave 勇敢的|funny 有趣的|lovely 可爱的|great 很棒的|ready 准备好的|surprised 惊讶的"),
    "time": ("时间航线", "day 一天|week 一周|year 一年|hour 小时|date 日期|time 时间|late 迟到的|soon 不久|now 现在|once 一次|today 今天|tomorrow 明天|yesterday 昨天|morning 早晨|afternoon 下午|evening 傍晚|night 夜晚|minute 分钟|second 秒|month 月|weekend 周末|early 早的|always 总是|often 经常|never 从不|sometimes 有时|before 之前|after 之后|again 再次|already 已经"),
    "technology": ("科技工坊", "app 应用|web 网络|key 按键|link 链接|file 文件|save 保存|send 发送|call 呼叫|chat 聊天|text 文字|phone 电话|computer 电脑|laptop 笔记本电脑|tablet 平板电脑|screen 屏幕|keyboard 键盘|printer 打印机|internet 互联网|website 网站|email 电子邮件|message 消息|online 在线的|download 下载|video 视频|radio 收音机|digital 数字的|battery 电池|electric 电力的|machine 机器|robot 机器人"),
}
TOPICS.update({
    "shopping": ("购物小达人", "sale 促销|price 价格|cost 花费|cash 现金|coin 硬币|money 钱|change 零钱|cheap 便宜的|expensive 昂贵的|customer 顾客|assistant 店员|receipt 收据|bill 账单|order 订单|offer 优惠|present 礼物|gift 礼品|pair 一双|piece 一件|pound 英镑|dollar 美元|cent 美分|euro 欧元|wallet 钱包|purse 小钱包|basket 篮子|plastic 塑料|bottle 瓶子|box 盒子"),
    "jobs": ("职业梦想家", "job 工作|work 劳动|boss 老板|staff 员工|actor 演员|artist 艺术家|baker 面包师|chef 厨师|cook 厨师|driver 司机|engineer 工程师|farmer 农民|journalist 记者|manager 经理|mechanic 机修工|musician 音乐家|pilot 飞行员|secretary 秘书|shopper 购物者|singer 歌手|waiter 男服务员|waitress 女服务员|worker 工人|writer 作家|dentist 牙医|business 商业|company 公司|meeting 会议|interview 面试"),
    "colours": ("色彩与形状", "red 红色|blue 蓝色|green 绿色|yellow 黄色|orange 橙色|purple 紫色|pink 粉色|brown 棕色|black 黑色|white 白色|grey 灰色|gold 金色|silver 银色|colour 颜色|light 浅色的|dark 深色的|bright 明亮的|round 圆的|circle 圆形|triangle 三角形|shape 形状|line 线条|point 点|side 边|middle 中间|top 顶部|bottom 底部|straight 直的|curly 卷曲的"),
    "countryside": ("乡野发现", "tree 树|leaf 叶子|flower 花|grass 草|plant 植物|wood 木头|stone 石头|rock 岩石|sand 沙子|field 田地|soil 土壤|seed 种子|rose 玫瑰|fruit 水果|water 水|earth 地球|world 世界|country 国家|nature 自然|north 北方|south 南方|east 东方|west 西方|valley 山谷|stream 小溪|ocean 海洋|desert 沙漠|moon 月亮|star 星星"),
    "communication": ("交流信号站", "hello 你好|hi 嗨|bye 再见|yes 是的|no 不|please 请|thanks 谢谢|sorry 抱歉|welcome 欢迎|excuse 原谅|pardon 请再说一次|word 单词|letter 字母|language 语言|English 英语|French 法语|German 德语|Spanish 西班牙语|Chinese 中文|talk 交谈|tell 告诉|say 说|spell 拼写|mean 意思是|reply 回复|invite 邀请|invitation 邀请函|news 消息|information 信息"),
    "routine": ("我的每一天", "wake 醒来|wash 清洗|clean 清洁|brush 刷|eat 吃|drink 喝|breakfast 早餐|lunch 午餐|dinner 晚餐|supper 晚饭|meal 一顿饭|snack 点心|shower 淋浴|toilet 卫生间|towel 毛巾|soap 肥皂|comb 梳子|toothbrush 牙刷|toothpaste 牙膏|tidy 整齐的|leave 离开|arrive 到达|return 返回|wait 等待|stay 停留|visit 拜访|walk 步行|live 居住|grow 成长"),
    "directions": ("寻路小队", "left 左边|right 右边|up 上面|down 下面|in 里面|out 外面|on 在上方|off 离开|near 附近|far 远处|here 这里|there 那里|inside 在内部|outside 在外部|above 在上方|below 在下方|under 在下面|over 越过|between 在两者之间|behind 在后面|opposite 在对面|around 周围|across 横穿|along 沿着|through 穿过|towards 朝向|away 离去|front 前面|next 下一个"),
    "describing": ("描述大世界", "big 大的|small 小的|large 宽大的|little 小巧的|long 长的|short 短的|tall 高的|low 低的|high 高处的|wide 宽的|narrow 窄的|heavy 重的|thin 薄的|thick 厚的|deep 深的|full 满的|empty 空的|new 新的|old 旧的|young 年幼的|strong 强壮的|weak 虚弱的|soft 柔软的|sweet 甜的|fresh 新鲜的|different 不同的"),
})
PHRASES = {
    "animals": [("Look at the bird.", "看看那只鸟。"), ("My dog can run.", "我的狗会跑。")],
    "food": [("I like apples.", "我喜欢苹果。"), ("Can I have some juice?", "我能喝点果汁吗？")],
    "school": [("Open your book.", "打开你的书。"), ("Write your name.", "写下你的名字。")],
    "home": [("Close the door.", "把门关上。"), ("My room is clean.", "我的房间很整洁。")],
    "family": [("This is my sister.", "这是我的姐姐或妹妹。"), ("My friend is kind.", "我的朋友很友善。")],
    "travel": [("Where is the station?", "车站在哪里？"), ("We travel by train.", "我们乘火车旅行。")],
    "sport": [("Our team can win!", "我们队能赢！"), ("Let's play tennis.", "我们打网球吧。")],
    "clothes": [("Put on your coat.", "穿上你的外套。"), ("These shoes are new.", "这些鞋是新的。")],
    "weather": [("It is sunny today.", "今天阳光明媚。"), ("The wind is cold.", "风很冷。")],
    "town": [("Turn left at the bank.", "在银行处左转。"), ("The park is near here.", "公园离这里很近。")],
    "body": [("Wash your hands.", "洗洗手。"), ("I need some rest.", "我需要休息一下。")],
    "hobbies": [("I can play the piano.", "我会弹钢琴。"), ("This song is great!", "这首歌真棒！")],
    "actions": [("Can you help me?", "你能帮我吗？"), ("Try again, please.", "请再试一次。")],
    "feelings": [("Are you ready?", "你准备好了吗？"), ("I feel happy today.", "我今天很开心。")],
    "time": [("See you tomorrow!", "明天见！"), ("It is time to go.", "该出发了。")],
    "technology": [("Save your work.", "保存你的作品。"), ("Send me a message.", "给我发条消息。")],
    "shopping": [("How much is this?", "这个多少钱？"), ("I need a new bag.", "我需要一个新包。")],
    "jobs": [("My aunt is a pilot.", "我的阿姨是飞行员。"), ("What is your dream job?", "你梦想的工作是什么？")],
    "colours": [("My hat is blue.", "我的帽子是蓝色的。"), ("Draw a red circle.", "画一个红色圆圈。")],
    "countryside": [("The flowers are lovely.", "这些花真可爱。"), ("Look at the stars!", "看看星星！")],
    "communication": [("How do you spell it?", "这个怎么拼写？"), ("Please say that again.", "请再说一遍。")],
    "routine": [("I walk to school.", "我走路去上学。"), ("Have some breakfast.", "吃点早餐吧。")],
    "directions": [("The shop is on your left.", "商店在你的左边。"), ("Go straight on.", "一直往前走。")],
    "describing": [("This box is heavy.", "这个盒子很重。"), ("The water is deep.", "水很深。")],
}

def build():
    entries, topics = [], []
    seen = set()
    for topic, (label, packed) in TOPICS.items():
        topics.append({"id": topic, "name": label})
        for item in packed.split("|"):
            word, meaning = item.split(" ", 1)
            assert word not in seen, word
            seen.add(word)
            entries.append({"text": word, "meaning": meaning, "topic": topic, "kind": "word"})
        entries.extend({"text": text, "meaning": meaning, "topic": topic, "kind": "phrase"} for text, meaning in PHRASES[topic])
    result = {"version": 1, "alignment": "Independently curated A1–A2 / KET practice; not a complete official examination list.", "reference": "https://www.cambridgeenglish.org/Images/506886-a2-key-2020-vocabulary-list.pdf", "topics": topics, "entries": entries}
    destination = Path(__file__).resolve().parents[1] / "data/a2-vocabulary.json"
    destination.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(seen)} unique words, {len(entries)-len(seen)} original phrases, {len(topics)} topics")

if __name__ == "__main__":
    build()
