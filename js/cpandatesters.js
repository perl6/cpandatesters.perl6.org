jQuery(document).ready(function($) {
    $(".clickableRow").click(function() {
        if ($(this).attr("href"))
            window.document.location = $(this).attr("href");
        else if ($(this).attr("data-toggle")) {
            var elem = $($(this).attr("data-toggle"));
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
