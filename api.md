# 宠物API接口文档

## 基础信息

- **请求域名**: `https://pet.laowaidrivetest.com`
- **数据格式**: JSON
- **字符编码**: UTF-8

## 公共参数

### 请求头

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| Authorization | string | 是 | Bearer token，登录后获取（部分接口不需要） |

### 请求参数

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

## 错误码说明

| 错误码 | 说明 |
| :--- | :--- |
| 0 | 成功 |
| 其他 | 失败，返回对应的错误信息 |

---

## 无需认证接口

### 1. 获取配置

**接口地址**: `/api/common/getConfig`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "config": {
            "key1": "value1",
            "key2": "value2"
        }
    }
}
```

### 2. 获取应用信息

**接口地址**: `/api/common/getAppInfo`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "info": {
            "id": 1,
            "name": "宠物APP",
            "logo": "https://example.com/logo.png",
            "version": "1.0.0"
        }
    }
}
```

### 3. 获取导航列表

**接口地址**: `/api/common/nav`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | int | 否 | 类型：1-中间导航，2-底部导航，默认1 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": [
        {
            "id": 1,
            "name": "导航1",
            "icon": "https://example.com/icon.png",
            "url": "/page/home"
        }
    ]
}
```

### 4. 获取语言列表

**接口地址**: `/api/common/getLanguage`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "title": "汉文",
                "font_name": "ch"
            },
            {
                "id": 2,
                "title": "民族语言",
                "font_name": "mz"
            }
        ],
        "nav_lang": [
            {
                "id": 1,
                "title": "汉文",
                "font_name": "ch"
            }
        ]
    }
}
```

### 5. 获取导航信息

**接口地址**: `/api/common/navigation`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": [
        {
            "name": "导航1",
            "national_name": "民族名称",
            "row": 2,
            "child": [
                {
                    "name": "子导航",
                    "national_name": "民族名称",
                    "img": "https://example.com/img.png",
                    "url_type": 1,
                    "url": "/page/home"
                }
            ]
        }
    ]
}
```

### 6. 获取套餐列表

**接口地址**: `/api/common/setMeal`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "1": [
            {
                "id": 1,
                "name": "普通会员",
                "price": 9.9,
                "days": 30,
                "description": "普通会员权益"
            }
        ],
        "2": [
            {
                "id": 2,
                "name": "高级会员",
                "price": 19.9,
                "days": 30,
                "description": "高级会员权益"
            }
        ]
    }
}
```

### 7. 获取Access Token

**接口地址**: `/api/common/getNew`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "access_token": "wx_xxx_token",
        "expires_in": 7200
    }
}
```

### 8. 获取Banner列表

**接口地址**: `/api/common/getBanner`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| banner_type | int | 否 | banner类型，默认0 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "image_url": "https://example.com/banner.png",
                "url": "https://example.com",
                "type": 1
            }
        ]
    }
}
```

### 9. UUID登录

**接口地址**: `/api/login/loginByUuid`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| uuid | string | 是 | 用户UUID |
| source | int | 否 | 来源，默认0 |
| device | string | 否 | 设备信息 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "id": 1,
        "username": "用户名",
        "avatar": "https://example.com/avatar.png",
        "token": "Bearer xxx",
        "phone": "13800138000"
    }
}
```

### 10. OpenId登录

**接口地址**: `/api/login/loginByOpenId`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| code | string | 是 | 微信授权code |
| source | int | 否 | 来源，默认0 |
| device | string | 否 | 设备信息 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "id": 1,
        "username": "用户名",
        "avatar": "https://example.com/avatar.png",
        "token": "Bearer xxx",
        "phone": "13800138000",
        "session_key": "xxx"
    }
}
```

### 11. 获取短信验证码

**接口地址**: `/api/login/getSmsCode`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| phone | string | 是 | 手机号 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "发送成功"
}
```

---

## 需要认证接口

### Base模块

#### 1. 文件上传

**接口地址**: `/api/base/upload`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | string | 是 | 文件类型 |
| file | file | 是 | 上传的文件 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "url": "https://example.com/uploads/xxx.jpg"
    }
}
```

#### 2. 本地图片上传

**接口地址**: `/api/base/uploadLocalImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type | string | 是 | 文件类型 |
| file | file | 是 | 上传的文件 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "url": "/uploads/temp/xxx.jpg"
    }
}
```

#### 3. 上传模拟图片

**接口地址**: `/api/base/uploadMimicImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| file | file | 是 | 上传的文件 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "url": "https://example.com/uploads/xxx.jpg"
    }
}
```

#### 4. 上传字体文件

**接口地址**: `/api/base/uploadTtf`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| file | file | 是 | 上传的字体文件 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "url": "https://example.com/uploads/font/xxx.ttf"
    }
}
```

#### 5. 删除文件

**接口地址**: `/api/base/delFile`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| path | string | 是 | 文件路径 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

---

### Index模块

#### 1. 获取弹窗信息

**接口地址**: `/api/index/pop`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": [
        {
            "id": 1,
            "img": "https://example.com/pop1.png",
            "url": "https://example.com"
        }
    ]
}
```

#### 2. 提交意见反馈

**接口地址**: `/api/index/opinion`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| name | string | 是 | 姓名 |
| phone | string | 是 | 手机号 |
| content | string | 是 | 反馈内容 |
| img | array | 否 | 图片数组 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "提交成功"
}
```

---

### Pet模块

#### 1. 生成宠物图片

**接口地址**: `/api/pet/generatePetImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| description | string | 是 | 描述参数 |
| image | string | 是 | 参考图片URL |
| style_id | int | 否 | 风格ID，不传则使用默认配置 |

**说明**: 
- 如果传入了style_id，系统会查询对应风格的图片和描述，替换默认的reference_img和prompt
- 如果没有传入style_id或style_id不存在，则使用配置中的默认reference_img和prompt

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "image_url": "https://example.com/pet/generated.jpg"
    }
}
```

#### 2. 获取宠物风格列表

**接口地址**: `/api/pet/getPetStyles`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用风格 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "name": "卡通风格",
                "image": "https://example.com/styles/cartoon.jpg",
                "description": "可爱的卡通风格，适合生成萌宠形象",
                "is_show": 1,
                "sort": 1,
                "created_at": "2024-01-01 10:00:00"
            }
        ]
    }
}
```

#### 3. 宠物图片抠图

**接口地址**: `/api/pet/mattingPetImage`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| image | string | 是 | 图片URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "task_id": "task_1234567890"
    }
}
```

**说明**: 此接口只负责创建抠图任务，不返回最终处理结果。前端需要使用返回的 `task_id` 调用 `getMattingTaskResult` 接口轮询获取处理结果。

#### 4. 获取抠图任务结果

**接口地址**: `/api/pet/getMattingTaskResult`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| task_id | string | 是 | 任务ID（从mattingPetImage接口获取） |

**返回示例**:

任务进行中：
```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": "processing",
        "message": "处理中..."
    }
}
```

任务完成：
```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": "completed",
        "image_url": "https://example.com/pet/matted.png"
    }
}
```

任务失败：
```json
{
    "code": 400,
    "msg": "背景移除失败：具体错误信息"
}
```

**说明**: 
- 前端需要轮询调用此接口获取任务结果
- 任务状态：`processing`-处理中，`completed`-完成，`failed`-失败
- 建议轮询间隔为2-3秒

#### 5. 创建宠物档案

**接口地址**: `/api/pet/createPetProfile`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| nickname | string | 是 | 宠物昵称 |
| image | string | 是 | 宠物图片URL |
| type | int | 否 | 宠物类型：1-小狗，2-小猫，3-其他，默认1 |
| description | string | 否 | 宠物描述 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "创建成功",
    "data": {
        "pet_id": 1
    }
}
```

#### 6. 获取宠物档案

**接口地址**: `/api/pet/getPetProfileInfo`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
<!-- | pet_id | int | 是 | 宠物ID | -->

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "info": [
            "id": 1,
            "nickname": "旺财",
            "image": "https://example.com/pet/1.png",
            "animated_image": "https://example.com/pet/1.gif",
            "type": 1,
            "description": "可爱的小狗",
            "is_default": 1,
            "is_show": 1
        ]
    }
}
```

**返回字段说明（info 列表项）**:

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| animated_image | string | 宠物召唤用 GIF 动图 URL；有值时前端召唤宠物直接使用，无需再调 GIF 生成接口 |

#### 5. 获取纪念日列表

**接口地址**: `/api/pet/getAnniversaryList`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 否 | 宠物ID，不传则返回所有宠物的纪念日 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "pet_id": 1,
                "type_id": 1,
                "name": "生日",
                "date": "2024-01-01",
                "date_type": 1,
                "repeat_frequency": 1,
                "is_top": 0,
                "is_remind": 1,
                "is_show": 1,
                "type": {
                    "id": 1,
                    "title": "生日",
                    "bg_color": "#FF6B6B",
                    "icon": "https://example.com/icon.png",
                    "is_system": 1,
                    "is_show": 1
                }
            }
        ]
    }
}
```

#### 6. 获取纪念日类型列表

**接口地址**: `/api/pet/getTypes`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 否 | 宠物ID，不传则返回所有类型 |
| language_id | int | 否 | 语言ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "title": "生日",
                "bg_color": "#FF6B6B",
                "icon": "https://example.com/icon.png",
                "is_system": 1,
                "is_show": 1
            }
        ]
    }
}
```

#### 7. 获取纪念日类型图标列表

**接口地址**: `/api/pet/getAnniversaryTypeIcons`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "image": "https://example.com/icon.png",
                "is_show": 1,
                "sort": 0
            }
        ]
    }
}
```

#### 8. 添加自定义纪念日类型

**接口地址**: `/api/pet/addCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| title | string | 是 | 类型标题 |
| pet_id | int | 是 | 宠物ID |
| bg_color | string | 否 | 背景颜色，默认#FF6B6B |
| icon | string | 否 | 图标URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "添加成功",
    "data": {
        "type_id": 1
    }
}
```

#### 9. 编辑自定义纪念日类型

**接口地址**: `/api/pet/editCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type_id | int | 是 | 类型ID |
| pet_id | int | 是 | 宠物ID |
| title | string | 是 | 类型标题 |
| bg_color | string | 否 | 背景颜色 |
| icon | string | 否 | 图标URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "编辑成功"
}
```

#### 10. 删除自定义纪念日类型

**接口地址**: `/api/pet/deleteCustomType`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| type_id | int | 是 | 类型ID |
| pet_id | int | 是 | 宠物ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

#### 11. 添加纪念日

**接口地址**: `/api/pet/addAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 是 | 宠物ID |
| name | string | 是 | 纪念日名称 |
| date | string | 是 | 日期（YYYY-MM-DD） |
| type_id | int | 否 | 类型ID，默认0 |
| date_type | int | 否 | 日期类型：1-公历，2-农历，默认1 |
| repeat_frequency | int | 否 | 重复频率：0-不重复，1-每天，2-每周，3-每月，4-每年，默认1 |
| is_top | int | 否 | 是否置顶：0-否，1-是，默认0 |
| is_remind | int | 否 | 是否提醒：0-否，1-是，默认0 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "添加成功",
    "data": {
        "anniversary_id": 1
    }
}
```

#### 11. 编辑纪念日

**接口地址**: `/api/pet/editAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| anniversary_id | int | 是 | 纪念日ID |
| pet_id | int | 否 | 宠物ID |
| type_id | int | 否 | 类型ID |
| name | string | 否 | 纪念日名称 |
| date | string | 否 | 日期 |
| date_type | int | 否 | 日期类型 |
| repeat_frequency | int | 否 | 重复频率：0-不重复，1-每天，2-每周，3-每月，4-每年 |
| is_top | int | 否 | 是否置顶 |
| is_remind | int | 否 | 是否提醒 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "编辑成功"
}
```

#### 13. 删除纪念日

**接口地址**: `/api/pet/deleteAnniversary`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| anniversary_id | int | 是 | 纪念日ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

#### 13. 切换默认宠物

**接口地址**: `/api/pet/reselectPet`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 是 | 宠物ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "切换成功"
}
```

#### 16. 获取字体样式列表

**接口地址**: `/api/pet/getFontStyles`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "name": "字体1",
                "images": "[\"https://example.com/font1.png\"]",
                "is_show": 1
            }
        ]
    }
}
```

#### 15. 获取背景列表

**接口地址**: `/api/pet/getBackgrounds`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID |
| category_id | int | 否 | 分类ID，不传则返回所有分类的背景 |
| my_user_id | int | 否 | 用户ID，传了则只返回该用户的背景和系统背景 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "category_id": 1,
                "user_id": 0,
                "name": "背景1",
                "image": "https://example.com/bg1.png",
                "is_show": 1,
                "created_at": "2024-01-01 10:00:00"
            }
        ]
    }
}
```

#### 16. 获取背景分类列表

**接口地址**: `/api/pet/getBackgroundCategories`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用分类 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "name": "节日背景",
                "is_show": 1,
                "sort": 1,
                "created_at": "2024-01-01 10:00:00"
            },
            {
                "id": 2,
                "app_id": 1,
                "language_id": 0,
                "name": "卡通背景",
                "is_show": 1,
                "sort": 2,
                "created_at": "2024-01-01 10:00:00"
            }
        ]
    }
}
```

#### 17. 上传自定义背景图片

**接口地址**: `/api/pet/uploadBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| image | string | 是 | 图片URL（先调用/api/base/upload上传） |
| name | string | 否 | 背景名称，默认"自定义背景" |
| user_id | int | 否 | 用户ID，不传则为0（系统背景） |

**返回示例**:

```json
{
    "code": 200,
    "msg": "上传成功",
    "data": {
        "id": 10,
        "image": "https://pet.laowaidrivetest.com/pet/background/app_1/custom_bg_1234567890_1234.png"
    }
}
```

#### 18. 更新背景图片

**接口地址**: `/api/pet/updateBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| id | int | 是 | 背景ID |
| name | string | 否 | 背景名称 |
| image | string | 否 | 新图片URL |
| category_id | int | 否 | 分类ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "更新成功"
}
```

#### 19. 删除背景图片

**接口地址**: `/api/pet/deleteBackground`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| id | int | 是 | 背景ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

#### 20. 图片加文本生成 GIF 动图

**接口地址**: `/api/pet/generateImageWithTextGif`

**请求方式**: POST

**使用场景**: 召唤宠物时，若档案 `animated_image` 为空，且 `getGifTaskResult` 返回 `status` 为 `null`（未生成），则调用本接口发起 GIF 生成。

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 是 | 宠物ID |
| image | string | 是 | 宠物静态图 URL（通常取档案 `image` 字段） |

**说明**: 文本内容从配置项 `gif_text` 中获取，默认值为「宠物纪念」。

**返回示例（提交成功）**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "image_url": "https://pet.laowaidrivetest.com/pet/gif/app_1/1234567890.gif"
    }
}
```

**返回字段说明**:

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| image_url | string | GIF 动图 URL。同步生成完成时直接返回；异步生成时可能为空，需轮询 `getGifTaskResult` 直至 `status=3` 后获取 |

**说明**:
- 本接口用于创建 GIF 生成任务；提交成功后任务状态变为 `0`（生成中）
- 前端应继续轮询 `getGifTaskResult`，在 `status=3` 时取 `image_url` 用于召唤宠物展示

#### 21. 获取 GIF 生成任务结果

**接口地址**: `/api/pet/getGifTaskResult`

**请求方式**: GET

**使用场景**: 召唤宠物时，若档案 `animated_image` 为空，先调用本接口查询当前宠物的 GIF 生成状态，再决定是否调用 `generateImageWithTextGif` 或轮询等待。

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| pet_id | int | 是 | 宠物ID |

**返回示例（未生成）**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": null,
        "message": ""
    }
}
```

**返回示例（生成中）**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": 0,
        "message": "生成中",
        "list": [
            { "key": 1, "status": 3 },
            { "key": 2, "status": 3 },
            { "key": 3, "status": 1 },
            { "key": 4, "status": 0 },
            { "key": 5, "status": 0 },
            { "key": 6, "status": 0 },
            { "key": 7, "status": 0 }
        ]
    }
}
```

**list 字段说明**（7 个步骤，首页召唤宠物进度提示使用）:

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| key | int | 步骤序号 `1`～`7` |
| status | int | 单步状态：`0`-未开始，`1`-进行中，`2`-失败，`3`-成功 |

前端进度条：`status=3` 实心完成；第一个 `status=1` 的格闪烁；`status=0` 浅色未开始。

**返回示例（生成成功）**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": 3,
        "message": "",
        "image_url": "https://pet.laowaidrivetest.com/pet/gif/app_1/1234567890.gif"
    }
}
```

**返回示例（生成失败）**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "status": 2,
        "message": "GIF生成失败：具体错误信息"
    }
}
```

**返回字段说明**:

| 字段名 | 类型 | 说明 |
| :--- | :--- | :--- |
| status | int \| null | 任务状态：`null`-未生成，`0`/`1`-生成中，`2`-失败，`3`-成功 |
| message | string | 状态说明或失败原因 |
| list | array | 7 步进度：`[{key, status}]`；`key` 为 1～7，`status`：`0`未开始 / `1`进行中 / `2`失败 / `3`成功 |
| image_url | string | GIF 动图 URL；仅任务 `status=3` 时返回 |

**前端召唤宠物 GIF 获取流程**:

1. 读取 `getPetProfileInfo` 返回的 `animated_image`；**有值则直接使用**，不再请求 GIF 相关接口
2. `animated_image` 为空时，调用 `getGifTaskResult` 查询任务状态
3. `status` 为 `null`：未生成 → 调用 `generateImageWithTextGif` 发起生成
4. `status` 为 `0` 或 `1`：生成中 → 轮询 `getGifTaskResult`（建议间隔 2～3 秒）
5. `status` 为 `2`：失败 → **从头重新调用** `generateImageWithTextGif`，再继续轮询
6. `status` 为 `3`：成功 → 使用 `image_url` 作为召唤宠物动图

**说明**: 无客户端超时；`status` 为 `0`/`1` 时持续轮询；`status=2` 时重新发起生成并继续等待，直至 `status=3`。

---

### User模块

#### 1. 获取用户信息

**接口地址**: `/api/user/getUserInfo`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "id": 1,
        "username": "用户名",
        "avatar": "https://example.com/avatar.png",
        "phone": "13800138000",
        "endtime": "2024-12-31 23:59:59",
        "is_vip": "1"
    }
}
```

#### 2. 更新用户信息

**接口地址**: `/api/user/updateUserInfo`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| username | string | 否 | 用户名 |
| password | string | 否 | 密码 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success"
}
```

#### 3. 更新用户头像

**接口地址**: `/api/user/updateUserAvatar`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| avatar | string | 否 | 头像URL |
| username | string | 否 | 用户名 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success"
}
```

#### 4. 更新免费次数

**接口地址**: `/api/user/updateUserFreeTimes`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success"
}
```

#### 5. 绑定手机号

**接口地址**: `/api/user/bindPhone`

**请求方式**: POST/GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| phone | string | 是 | 手机号 |
| code | string | 是 | 验证码 |
| type | int | 否 | 类型：1-验证码验证，默认1 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success"
}
```

#### 6. 注销账号

**接口地址**: `/api/user/cancelAccount`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "注销成功"
}
```

---

### Camera模块

#### 1. 获取音效分类列表

**接口地址**: `/api/camera/getSoundCategories`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用分类 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": [
        {
            "id": 1,
            "app_id": 1,
            "language_id": 0,
            "name": "动物叫声",
            "icon": "https://example.com/icons/animal.png",
            "is_show": 1,
            "sort": 1
        },
        {
            "id": 2,
            "app_id": 1,
            "language_id": 0,
            "name": "搞笑音效",
            "icon": "https://example.com/icons/funny.png",
            "is_show": 1,
            "sort": 2
        }
    ]
}
```

#### 2. 获取音效列表

**接口地址**: `/api/camera/getSoundEffects`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| language_id | int | 否 | 语言ID，不传则返回通用音效 |
| category_id | int | 否 | 分类ID，不传则返回全部分类 |
| page | int | 否 | 页码，默认1 |
| page_size | int | 否 | 每页数量，默认20 |

**排序规则**: 用户设置的排序 > 推荐 > 默认ID倒序

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "language_id": 0,
                "category_id": 1,
                "category_name": "动物叫声",
                "name": "狗叫声",
                "sound_url": "https://example.com/sounds/dog.mp3",
                "image_url": "https://example.com/images/dog.png",
                "sound_type": 1,
                "is_recommend": 1,
                "is_show": 1,
                "sort": 1,
                "created_at": "2024-01-01 10:00:00"
            }
        ],
        "pagination": {
            "total": 100,
            "current_page": 1,
            "per_page": 20
        }
    }
}
```

#### 3. 设置音效排序

**接口地址**: `/api/camera/setSoundEffectSort`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| sort_list | array | 是 | 音效排序数组，格式：[{"sound_effect_id": 1, "sort": 1}, {"sound_effect_id": 2, "sort": 2}] |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功"
}
```

#### 4. 添加用户自定义音效

**接口地址**: `/api/camera/addCustomSoundEffect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| name | string | 是 | 音效名称 |
| sound_url | string | 是 | 音效文件URL |
| category_id | int | 是 | 分类ID |
| image_url | string | 否 | 音效图片URL |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功",
    "data": {
        "effect_id": 1
    }
}
```

#### 5. 删除用户自定义音效

**接口地址**: `/api/camera/deleteCustomSoundEffect`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| effect_id | int | 是 | 音效ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

#### 6. 保存摄像头记录

**接口地址**: `/api/camera/saveCameraRecord`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| file_url | string | 是 | 文件URL（图片或视频） |
| record_type | int | 否 | 记录类型：1-图片 2-视频，默认1 |
| sound_effect_id | int | 否 | 使用的音效ID |
| thumbnail_url | string | 否 | 缩略图URL（视频时使用） |
| duration | int | 否 | 视频时长（秒） |

**返回示例**:

```json
{
    "code": 200,
    "msg": "保存成功",
    "data": {
        "record_id": 1
    }
}
```

#### 7. 获取摄像头记录列表

**接口地址**: `/api/camera/getCameraRecords`

**请求方式**: GET

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| record_type | int | 否 | 记录类型：1-图片 2-视频 |

**返回示例**:

```json
{
    "code": 200,
    "msg": "success",
    "data": {
        "list": [
            {
                "id": 1,
                "app_id": 1,
                "user_id": 1001,
                "record_type": 1,
                "file_url": "https://example.com/camera/photo_123.jpg",
                "thumbnail_url": null,
                "duration": 0,
                "sound_effect_id": 1,
                "is_show": 1,
                "created_at": "2024-01-01 10:00:00"
            }
        ],
        "pagination": {
            "total": 100,
            "current_page": 1,
            "per_page": 20
        }
    }
}
```

#### 8. 删除摄像头记录

**接口地址**: `/api/camera/deleteCameraRecord`

**请求方式**: POST

**请求参数**:

| 参数名 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| app_id | int | 是 | 应用ID |
| record_id | int | 是 | 记录ID |

**返回示例**:

```json
{
    "code": 200,
    "msg": "删除成功"
}
```

---