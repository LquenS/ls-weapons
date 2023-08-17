let Attachments = {}
const closeAttachmentScreen = () => {
    $(".attachment-visible").hide()
    $.post("https://ls-weapons/closeAttachment")
}

const openAttachmentScreen = () => {
    $(".attachment-visible").show() 
}

const setupItems = (data) => {
    const $list = $(".attachments-list")
    $list.empty()

    $.each(data.items, function(_, value) {
        if (value != null) {
            const key = Object.keys(Attachments).find(key => Attachments[key].item === value.name);
            if ( key ) {
                value.attachableto = Attachments[key].type
                value.attachmenttype = Attachments[key]
                $list.append(`<div class="inv-list-item" id="item-${value.slot}">
                        <div class="inv-label">${value.label}</div>
                        <img src="nui://ls-inventory/web/images/${value.image}" class="inv-img">
                    </div>`)
    
                $(`#item-${value.slot}`).data("itemData", value)
            }
        }
    })

    setupDraggableDroppable()
}

const setupDraggableDroppable = () => {
    $(".inv-list-item").draggable({
        revert: true,
        revertDuration: 0,
        appendTo: "body",
        helper: "clone",
    })

    $(".attachment-box").droppable({
        drop: (e, ui) => {
            if ($(e.target).attr("isoccuiped") == "true")
                return false;

            $(".hover-box").removeClass("hover-box")

            const item = ui.draggable.data("itemData")
            if (item.attachableto == $(e.target).attr("attachment")) {
                AudioPlay("sounds/attachment.wav", .3, true)
                
                $.post("https://ls-weapons/attachAttachment", JSON.stringify({ item: item }))

                ui.draggable.remove()
            }
        },
        over: (e, ui) => {
            const item = ui.draggable.data("itemData")

            if (item.attachableto == $(e.target).attr("attachment")) {
                $(e.target).addClass("hover-box")
            }
        },
        out: () => {
            $(".hover-box").removeClass("hover-box")
        }
    })

    $(".attachment-inner-item").draggable({
        revert: true,
        revertDuration: 0,
        appendTo: "body",
        helper: "clone",
        stop: (e, ui) => {
            const $loc = $(document.elementFromPoint(e.pageX, e.pageY))
            
            if ($loc.get(0).classList[0] == "attachments-list") {

                AudioPlay("sounds/attachment.wav", .3, true)

                $.post("https://ls-weapons/removeAttachment", JSON.stringify({ item: $(e.target).data("itemData") }))

                $(e.target).remove()
            }
        }
    })
}

$(document).ready(() => {
    window.addEventListener("message", (event) => {
        switch (event.data.action) {
            case "open":
                openAttachmentScreen(event.data)
                break;
            case "close":
                closeAttachmentScreen()
                break;
            case "update":
                DrawAttachmentBox(event.data.attachments, event.data.weaponData)
                setupItems(event.data)
                break;
            case "updateWeaponAttachmentMenu":
                Attachments = event.data.attachmentItems
                DrawAttachmentBox(event.data.attachments, event.data.weaponData)
                setupItems(event.data)
                break;
        }
    });

    $(document).on('keydown', (e) => {
        switch(e.keyCode) {
            case 27:
                closeAttachmentScreen()
        }
    });
})

DrawAttachmentBox = (data, weaponData) => {
    $.each(data, function(__, value) {
        if (!value.display)
             return $(`#attachment-${value.attach_component}`).hide();
        else
            $(`#attachment-${value.attach_component}`).show();

        $(`#attachment-${value.attach_component}`).attr("attachment", value.attach_component)

        let addSome = {x: 0, y:0}
        if (value.attach_component == "scope")
            addSome.y -= 5

        if (value.attach_component == "grip")
            addSome.y += 5

        if (value.attach_component == "flashlight")
            addSome.x -= 5

        if (value.attach_component == "tint")
            addSome.y -= 8

        // weaponData.info.attachments is an Object and Attachments an object too, and i n
        let itemObj = FindCorrectAttachment(value.attach_component, weaponData.info.attachments)
        $(`#attachment-${value.attach_component}`).css({"left": value.x + addSome.x + "%", "top": value.y + addSome.y + "%"}).html(`
        <div class="attachment-label">
            ${value.label}
        </div>
        
        
        <div class="attachment-item">
            ${itemObj ? `<div class="attachment-inner-item" id="item-main-${itemObj.item}">
                <img src="nui://ls-inventory/web/images/${itemObj.image}" alt="No image found :(">
            </div>` : ""}
        </div>`).attr("isoccuiped", itemObj ? true : false)

        if (itemObj) {
            $("#item-main-"+itemObj.item).data("itemData", itemObj)
        }
    })

    setupDraggableDroppable()
}

FindCorrectAttachment = (comp, attachments) => {
    let item = false;
    if (attachments) {
        $.each(attachments, function(key, value) {
            if (key == comp || ( value.type != undefined && value.type == comp)) {
                if (Object.values(attachments).find(x => x.item == value.item) != undefined) {
                    item = Object.values(attachments).find(x => x.item == value.item)
                    item.attachableto = key
                }
            }
        })
    }
    return item
}


let isAudioPlaying = false;
AudioPlay = (name, volume = 1, bypass = false) => {
    if (isAudioPlaying && !bypass)
        return false;

    isAudioPlaying = true

    var sound = new Audio(name);
    sound.volume = volume;
    sound.play();
    sound.addEventListener('ended', () => {
        isAudioPlaying = false
    });

    return sound;
}