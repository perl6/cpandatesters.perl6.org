jQuery(document).ready(function($) {
    $(".clickableRow").click(function() {
        if ($(this).attr("href"))
            window.document.location = $(this).attr("href");
        else if ($(this).attr("data-toggle")) {
            var elem = $($(this).attr("data-toggle"));
            if(elem.hasClass("out")) {
                elem.addClass("in");
                elem.removeClass("out");
            }
            else {
                elem.addClass("out");
                elem.removeClass("in");
            }
        }
    });
});
