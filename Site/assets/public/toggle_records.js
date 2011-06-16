<script>
  $(document).ready(function(){
    $('div.records').hide();
    $("a.records").live('click', function(){ 
      $(this).closest('div.ip').find('div.records').toggle();
    });
  });
</script>