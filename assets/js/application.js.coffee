#= require jquery-1.8.2.min.js

$ ->
  $('#form').submit ->
    $amount = $(this).find('input[name="prompt[amount]"]')

    unless !isNaN(parseFloat($amount.val())) && isFinite($amount.val())
      $amount.css
        border: '1px solid red'
      false