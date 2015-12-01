jQuery(document).ready(function($) {
    $(".clickableRow").click(function() {
        var queryAttr;
        if (queryAttr = $(this).find("a").attr("href"))
            window.document.location = queryAttr;
        else if (queryAttr = $(this).attr("data-toggle")) {
            var elem = $(queryAttr);
            if(elem.hasClass("out")) {
                elem.fadeIn();
                elem.removeClass("out");
            }
            else {
                elem.fadeOut();
                elem.addClass("out");
            }
        }
    });
});
